import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firestore Service

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private var db: Firestore { FirebaseConfig.shared.db }

    /// Bumped whenever the current user's circle membership changes
    /// (invite auto-accept, manual join, default-circle creation). Views that
    /// depend on circle data observe this and refetch on change — otherwise
    /// they'd stay stuck on whatever they cached on first `.task`.
    @Published var circlesVersion: Int = 0

    /// Cached "default" circle ID for the current user, populated as a side
    /// effect of `getMyCircles()`. RestaurantStore reads this synchronously
    /// to push local edits to Firestore without triggering a circles query
    /// on every save. Nil until any view has fetched circles at least once
    /// this session (ContentView does on app start).
    @Published var primaryCircleId: String?

    private init() {}

    // MARK: - User Profile

    struct UserProfile: Codable {
        var uid: String
        var displayName: String
        var username: String
        var email: String
        var profileImageURL: String
        var circleIds: [String]
        var createdAt: Date
        var updatedAt: Date

        init(uid: String, displayName: String, username: String = "", email: String, profileImageURL: String = "", circleIds: [String], createdAt: Date, updatedAt: Date) {
            self.uid = uid
            self.displayName = displayName
            self.username = username.isEmpty ? Self.generateUsername(from: displayName) : username
            self.email = email
            self.profileImageURL = profileImageURL
            self.circleIds = circleIds
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "User"
            email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
            profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL) ?? ""
            circleIds = try container.decodeIfPresent([String].self, forKey: .circleIds) ?? []
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
            let rawUsername = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
            username = rawUsername.isEmpty ? Self.generateUsername(from: displayName) : rawUsername
        }

        static func generateUsername(from displayName: String) -> String {
            let cleaned = displayName
                .lowercased()
                .components(separatedBy: .whitespaces)
                .joined()
                .filter { $0.isLetter || $0.isNumber }
            return cleaned.isEmpty ? "user" : cleaned
        }
    }

    func createUserProfileIfNeeded(for user: User) async {
        let ref = db.collection("users").document(user.uid)

        do {
            let doc = try await ref.getDocument()
            if !doc.exists {
                let displayName = user.displayName ?? "User"
                let profile = UserProfile(
                    uid: user.uid,
                    displayName: displayName,
                    username: UserProfile.generateUsername(from: displayName),
                    email: user.email ?? "",
                    profileImageURL: "",
                    circleIds: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try ref.setData(from: profile)

                // Auto-create a default circle for new users
                let circle = try await createCircle(
                    name: "\(profile.displayName)'s Table",
                    ownerId: user.uid
                )
                // Add circle ID to user profile
                try await ref.updateData(["circleIds": FieldValue.arrayUnion([circle.id])])
                // Signal to observers (Home/Table tabs) that circle membership
                // just changed so they refetch.
                circlesVersion &+= 1
            }
        } catch {
            print("Error creating user profile: \(error)")
        }
    }

    func getUserProfile(uid: String) async -> UserProfile? {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard doc.exists, let data = doc.data() else { return nil }
            // Manual decode to handle missing/null fields gracefully
            let displayName = data["displayName"] as? String ?? "User"
            let rawUsername = data["username"] as? String ?? ""
            return UserProfile(
                uid: data["uid"] as? String ?? uid,
                displayName: displayName,
                username: rawUsername.isEmpty ? UserProfile.generateUsername(from: displayName) : rawUsername,
                email: data["email"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String ?? "",
                circleIds: data["circleIds"] as? [String] ?? [],
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        } catch {
            print("Error getting user profile: \(error)")
            return nil
        }
    }

    func updateUsername(_ username: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).updateData([
            "username": username,
            "updatedAt": Date()
        ])
    }

    // MARK: - Taste Preferences

    func saveTastePreferences(_ prefs: TastePreferences) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "favoriteCuisines": prefs.favoriteCuisines.map(\.rawValue),
            "diningFrequency": prefs.diningFrequency?.rawValue ?? "",
            "onboardingCompleted": prefs.onboardingCompleted,
            "updatedAt": Date()
        ]
        try await db.collection("users").document(uid).updateData([
            "tastePreferences": data
        ])
    }

    func getTastePreferences() async -> TastePreferences {
        guard let uid = Auth.auth().currentUser?.uid else { return TastePreferences() }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(),
                  let prefsData = data["tastePreferences"] as? [String: Any] else {
                return TastePreferences()
            }
            let cuisineStrings = prefsData["favoriteCuisines"] as? [String] ?? []
            let cuisines = cuisineStrings.compactMap { CuisineType(rawValue: $0) }
            let freqString = prefsData["diningFrequency"] as? String ?? ""
            let frequency = DiningFrequency(rawValue: freqString)
            let completed = prefsData["onboardingCompleted"] as? Bool ?? false
            return TastePreferences(favoriteCuisines: cuisines, diningFrequency: frequency, onboardingCompleted: completed)
        } catch {
            print("Error loading taste preferences: \(error)")
            return TastePreferences()
        }
    }

    // MARK: - Circles

    struct Circle: Codable, Identifiable {
        @DocumentID var documentId: String?
        var id: String { documentId ?? "" }
        var name: String = ""
        var ownerId: String = ""
        var memberIds: [String] = []
        var inviteCode: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        init(name: String, ownerId: String, memberIds: [String], inviteCode: String, createdAt: Date, updatedAt: Date) {
            self.name = name
            self.ownerId = ownerId
            self.memberIds = memberIds
            self.inviteCode = inviteCode
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    struct CircleMember: Identifiable {
        var id: String { uid }
        var uid: String
        var displayName: String
    }

    func createCircle(name: String, ownerId: String) async throws -> Circle {
        let inviteCode = generateInviteCode()
        let circle = Circle(
            name: name,
            ownerId: ownerId,
            memberIds: [ownerId],
            inviteCode: inviteCode,
            createdAt: Date(),
            updatedAt: Date()
        )
        let ref = try db.collection("circles").addDocument(from: circle)
        var created = circle
        created.documentId = ref.documentID
        return created
    }

    func getMyCircles() async -> [Circle] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        do {
            let snapshot = try await db.collection("circles")
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()
            let circles = snapshot.documents.compactMap { try? $0.data(as: Circle.self) }
            // Cache the first circle as the user's "primary" so RestaurantStore
            // can push edits without re-fetching. Prefer a circle the user
            // owns (their default table) over one they joined, so pushes
            // don't pollute a friend's table with our updates.
            let ownedFirst = circles.sorted { a, b in
                let aOwned = (a.ownerId == uid) ? 0 : 1
                let bOwned = (b.ownerId == uid) ? 0 : 1
                return aOwned < bOwned
            }
            if let first = ownedFirst.first, primaryCircleId != first.id {
                primaryCircleId = first.id
            }
            return circles
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }

    func joinCircle(inviteCode: String) async throws -> Circle? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }

        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw CircleError.invalidCode
        }

        var circle = try doc.data(as: Circle.self)

        if circle.memberIds.contains(uid) {
            throw CircleError.alreadyMember
        }

        // Add user to circle
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid]),
            "updatedAt": Date()
        ])

        // Add circle to user profile
        try await db.collection("users").document(uid).updateData([
            "circleIds": FieldValue.arrayUnion([circle.id])
        ])

        circle.memberIds.append(uid)
        return circle
    }

    func getCircleMembers(circle: Circle) async -> [CircleMember] {
        var members: [CircleMember] = []
        for uid in circle.memberIds {
            if let profile = await getUserProfile(uid: uid) {
                members.append(CircleMember(uid: uid, displayName: profile.displayName))
            }
        }
        return members
    }

    func regenerateInviteCode(circleId: String) async throws -> String {
        let newCode = generateInviteCode()
        try await db.collection("circles").document(circleId).updateData([
            "inviteCode": newCode,
            "updatedAt": Date()
        ])
        return newCode
    }

    // MARK: - Table Join Requests

    struct TableRequest: Codable, Identifiable {
        var id: String  // document ID
        var requesterId: String
        var requesterName: String
        var circleId: String
        var circleName: String
        var status: String  // "pending", "approved", "declined"
        var createdAt: Date

        init(id: String = "", requesterId: String, requesterName: String, circleId: String, circleName: String, status: String = "pending", createdAt: Date = Date()) {
            self.id = id
            self.requesterId = requesterId
            self.requesterName = requesterName
            self.circleId = circleId
            self.circleName = circleName
            self.status = status
            self.createdAt = createdAt
        }
    }

    /// Send a join request instead of auto-joining
    func requestToJoinTable(inviteCode: String) async throws -> TableRequest? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let displayName = Auth.auth().currentUser?.displayName ?? "User"

        // Find the circle by invite code
        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw CircleError.invalidCode
        }

        let circle = try doc.data(as: Circle.self)

        if circle.memberIds.contains(uid) {
            throw CircleError.alreadyMember
        }

        // Check if there's already a pending request
        let existingRequests = try await db.collection("tableRequests")
            .whereField("requesterId", isEqualTo: uid)
            .whereField("circleId", isEqualTo: circle.id)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()

        if !existingRequests.documents.isEmpty {
            throw CircleError.requestAlreadyPending
        }

        // Create the request
        let request = TableRequest(
            requesterId: uid,
            requesterName: displayName,
            circleId: circle.id,
            circleName: circle.name,
            status: "pending",
            createdAt: Date()
        )

        let data: [String: Any] = [
            "requesterId": request.requesterId,
            "requesterName": request.requesterName,
            "circleId": request.circleId,
            "circleName": request.circleName,
            "ownerId": circle.ownerId,
            "status": "pending",
            "createdAt": Date()
        ]

        let ref = try await db.collection("tableRequests").addDocument(data: data)
        var created = request
        created.id = ref.documentID
        return created
    }

    /// Get pending requests for circles the current user owns
    func getPendingRequests() async -> [TableRequest] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        do {
            let snapshot = try await db.collection("tableRequests")
                .whereField("ownerId", isEqualTo: uid)
                .whereField("status", isEqualTo: "pending")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc -> TableRequest? in
                let data = doc.data()
                return TableRequest(
                    id: doc.documentID,
                    requesterId: data["requesterId"] as? String ?? "",
                    requesterName: data["requesterName"] as? String ?? "Unknown",
                    circleId: data["circleId"] as? String ?? "",
                    circleName: data["circleName"] as? String ?? "",
                    status: data["status"] as? String ?? "pending",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        } catch {
            print("Error fetching pending requests: \(error)")
            return []
        }
    }

    /// Approve a join request: add requester to owner's table AND add owner to requester's table
    func approveRequest(_ request: TableRequest) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1. Add requester to the owner's circle
        try await db.collection("circles").document(request.circleId).updateData([
            "memberIds": FieldValue.arrayUnion([request.requesterId]),
            "updatedAt": Date()
        ])

        // 2. Add the circle to the requester's profile
        try await db.collection("users").document(request.requesterId).updateData([
            "circleIds": FieldValue.arrayUnion([request.circleId])
        ])

        // 3. Mutual join: add the owner to the requester's default table
        let requesterCircles = try await db.collection("circles")
            .whereField("ownerId", isEqualTo: request.requesterId)
            .limit(to: 1)
            .getDocuments()

        if let requesterCircleDoc = requesterCircles.documents.first {
            let requesterCircle = try requesterCircleDoc.data(as: Circle.self)
            if !requesterCircle.memberIds.contains(uid) {
                // Add owner to requester's table
                try await requesterCircleDoc.reference.updateData([
                    "memberIds": FieldValue.arrayUnion([uid]),
                    "updatedAt": Date()
                ])
                // Add requester's circle to owner's profile
                try await db.collection("users").document(uid).updateData([
                    "circleIds": FieldValue.arrayUnion([requesterCircle.id])
                ])
            }
        }

        // 4. Mark request as approved
        try await db.collection("tableRequests").document(request.id).updateData([
            "status": "approved"
        ])
    }

    /// Decline a join request
    func declineRequest(_ request: TableRequest) async throws {
        try await db.collection("tableRequests").document(request.id).updateData([
            "status": "declined"
        ])
    }

    // MARK: - Invite Auto-Accept (no approval step)
    //
    // Used by the deep-link handler: when B taps an invite link from A,
    // B is immediately added to A's circle *and* A is immediately added to
    // B's circle. No owner approval required.
    //
    // Security note: Firestore rules allow any authenticated user to update
    // a circle as long as they end up in memberIds, and B owns B's own circle
    // so the reverse add is always allowed. Adding the circle to A's
    // user.circleIds is blocked by rules (only A can write A's user doc),
    // but that's fine — getMyCircles() discovers circles by memberIds, not
    // by user.circleIds.

    /// Result of accepting an invite link.
    struct InviteAcceptResult {
        let circle: Circle          // the circle B joined (A's circle)
        let alreadyMember: Bool     // true if B was already in it
    }

    /// Accept an invite code and perform a mutual join.
    /// Ensures the current user has a circle (creating one if needed) so the
    /// inviter can be reciprocally added.
    func acceptInvite(inviteCode: String) async throws -> InviteAcceptResult {
        guard let uid = Auth.auth().currentUser?.uid,
              let user = Auth.auth().currentUser else {
            throw CircleError.invalidCode
        }

        // Make sure the accepter has a user profile + their own default circle.
        // createUserProfileIfNeeded is idempotent (checks !doc.exists), so this
        // is safe even if the profile already exists.
        await createUserProfileIfNeeded(for: user)

        // 1. Look up the inviter's circle by code.
        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw CircleError.invalidCode
        }
        var inviterCircle = try doc.data(as: Circle.self)

        // Already a member? Still do the reciprocal add in case we got here
        // on a stale state, but otherwise this is a no-op.
        let alreadyMember = inviterCircle.memberIds.contains(uid)

        // 2. Add B to A's circle.
        if !alreadyMember {
            try await doc.reference.updateData([
                "memberIds": FieldValue.arrayUnion([uid]),
                "updatedAt": Date()
            ])
            inviterCircle.memberIds.append(uid)

            // 3. Add A's circle to B's user.circleIds (own doc, allowed).
            try await db.collection("users").document(uid).updateData([
                "circleIds": FieldValue.arrayUnion([inviterCircle.id])
            ])
        }

        // 4. Reciprocal add: add A (inviterCircle.ownerId) to B's circle.
        // B owns their own circle and can update it freely.
        let ownerUid = inviterCircle.ownerId
        if ownerUid != uid {
            let mine = try await db.collection("circles")
                .whereField("ownerId", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            if let myDoc = mine.documents.first {
                let myCircle = try myDoc.data(as: Circle.self)
                if !myCircle.memberIds.contains(ownerUid) {
                    try await myDoc.reference.updateData([
                        "memberIds": FieldValue.arrayUnion([ownerUid]),
                        "updatedAt": Date()
                    ])
                }
            }
            // (We intentionally do NOT write to A's user.circleIds — Firestore
            // rules block that, and circle discovery uses memberIds anyway.)
        }

        // Signal to observers (Home/Table tabs) that circle membership just
        // changed so they refetch and the tester immediately sees the inviter's
        // table populate, instead of having to kill and reopen the app.
        circlesVersion &+= 1

        return InviteAcceptResult(circle: inviterCircle, alreadyMember: alreadyMember)
    }

    // MARK: - Restaurant Sync

    /// Push a local restaurant to Firestore under a circle.
    ///
    /// The payload mirrors the full `Restaurant` model — not just the fields
    /// the original circle-sharing feature needed — so the user's notes,
    /// reaction, occasion tags, 3-way dish verdicts, go-to flag, etc. all
    /// round-trip through the cloud. This is what lets us (a) restore state
    /// on a new device, and (b) use the data later for recommendations.
    func syncRestaurant(_ restaurant: Restaurant, circleId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Each dish serializes its full metadata so collapse-to-liked isn't
        // the only thing we preserve. Legacy rows without a verdict write
        // a null key, which stays back-compat with the existing reader.
        let dishPayload: [[String: Any]] = restaurant.dishes.map { dish in
            var d: [String: Any] = [
                "name": dish.name,
                "liked": dish.liked,
                "emoji": dish.emoji,
                "isLead": dish.isLead
            ]
            if let verdict = dish.verdict {
                d["verdict"] = verdict.rawValue
            }
            return d
        }

        var data: [String: Any] = [
            "userId": uid,
            "name": restaurant.name,
            "address": restaurant.address,
            "cuisine": restaurant.cuisine.rawValue,
            "category": restaurant.category.rawValue,
            "rating": restaurant.rating,
            "notes": restaurant.notes,
            "recommendedBy": restaurant.recommendedBy,
            "dishes": dishPayload,
            "dateAdded": restaurant.dateAdded,
            "dateVisited": restaurant.dateVisited ?? Date(),
            "visitCount": restaurant.visitCount,
            "quickNote": restaurant.quickNote,
            "personalNote": restaurant.personalNote,
            "isGoTo": restaurant.isGoTo,
            "goToNudgeShown": restaurant.goToNudgeShown,
            "saveReason": restaurant.saveReason,
            "occasionTags": restaurant.occasionTags.map(\.rawValue),
            "updatedAt": Date()
        ]

        // Reaction is optional — only write it when set so we don't clobber
        // a real reaction with an empty string.
        if let reaction = restaurant.reaction {
            data["reaction"] = reaction.rawValue
        }

        // Include Google Place ID if resolved — lets other devices skip the
        // resolver on their end.
        if let placeId = restaurant.googlePlaceId, !placeId.isEmpty {
            data["googlePlaceId"] = placeId
        }

        // Include coordinates if available
        if let lat = restaurant.latitude, let lng = restaurant.longitude {
            data["latitude"] = lat
            data["longitude"] = lng
        }

        try await db.collection("circles").document(circleId)
            .collection("restaurants").document(restaurant.id.uuidString)
            .setData(data, merge: true)
    }

    /// Fetch all restaurants from a circle (all members)
    func getCircleRestaurants(circleId: String) async -> [SharedRestaurant] {
        do {
            let snapshot = try await db.collection("circles").document(circleId)
                .collection("restaurants")
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc -> SharedRestaurant? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let userId = data["userId"] as? String else { return nil }

                let dishData = data["dishes"] as? [[String: Any]] ?? []
                let dishes = dishData.map { d -> DishItem in
                    // Prefer verdict when present — DishItem's init will
                    // derive `liked` from it — and fall back to the old
                    // `liked` bool for rows written before verdict existed.
                    let verdict = (d["verdict"] as? String).flatMap(DishVerdict.init(rawValue:))
                    let emoji = d["emoji"] as? String ?? "🍽️"
                    let isLead = d["isLead"] as? Bool ?? false
                    let liked = d["liked"] as? Bool ?? true
                    return DishItem(
                        name: d["name"] as? String ?? "",
                        liked: liked,
                        emoji: emoji,
                        isLead: isLead,
                        verdict: verdict
                    )
                }

                return SharedRestaurant(
                    id: doc.documentID,
                    userId: userId,
                    name: name,
                    address: data["address"] as? String ?? "",
                    cuisine: CuisineType(rawValue: data["cuisine"] as? String ?? "") ?? .other,
                    rating: data["rating"] as? Int ?? 0,
                    notes: data["notes"] as? String ?? "",
                    dishes: dishes,
                    visitCount: data["visitCount"] as? Int ?? 1,
                    dateVisited: (data["dateVisited"] as? Timestamp)?.dateValue(),
                    latitude: data["latitude"] as? Double,
                    longitude: data["longitude"] as? Double
                )
            }
        } catch {
            print("Error fetching circle restaurants: \(error)")
            return []
        }
    }

    // MARK: - Visit History (append-only)
    //
    // Each log-flow save writes a single, immutable Visit document. Unlike
    // the `restaurants/{id}` doc — which is overwritten with the "current"
    // aggregate state (visitCount, last note, etc.) — visits are an audit
    // trail: one row per "I went here" tap, preserving the date, the
    // dishes-and-verdicts snapshot, and whatever note the user typed that
    // night. This is what future views will draw from for "your history at
    // this restaurant" or per-visit share cards, and what future ML would
    // use to learn the user's taste over time without losing the raw signal.

    struct VisitDishLog: Codable {
        var name: String
        var verdict: String?  // raw DishVerdict value, or nil if not captured
        var liked: Bool       // derived convenience for legacy readers
    }

    /// Append a visit record to a restaurant's history. Fire-and-forget from
    /// callers — failures are logged but don't block the UI.
    func logVisit(
        restaurantId: UUID,
        circleId: String,
        date: Date,
        note: String,
        reaction: Reaction?,
        dishes: [DishItem],
        occasions: [OccasionTag]
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let dishPayload: [[String: Any]] = dishes.map { dish in
            var d: [String: Any] = [
                "name": dish.name,
                "liked": dish.liked
            ]
            if let verdict = dish.verdict {
                d["verdict"] = verdict.rawValue
            }
            return d
        }

        var data: [String: Any] = [
            "userId": uid,
            "date": date,
            "note": note,
            "dishes": dishPayload,
            "occasions": occasions.map(\.rawValue),
            "createdAt": Date()
        ]
        if let reaction = reaction {
            data["reaction"] = reaction.rawValue
        }

        // Firestore auto-assigns a document ID here — we don't need a
        // client-side UUID because visits aren't referenced by other
        // records; they're only read back as a collection, ordered by date.
        try await db.collection("circles").document(circleId)
            .collection("restaurants").document(restaurantId.uuidString)
            .collection("visits")
            .addDocument(data: data)
    }

    /// Patch the most-recent visit's dish list — used by the "I forgot to
    /// add some dishes" flow on Place memory. Looks up the newest visit by
    /// date and merges in the new dish payloads. We patch instead of
    /// writing a new visit so we don't fabricate phantom visit records
    /// for "oh, I also had the kebab" edits.
    ///
    /// If there are no existing visits (shouldn't normally happen — the
    /// caller is editing a place that's been logged at least once), we
    /// just no-op rather than create one with a wrong date.
    func appendDishesToLatestVisit(
        restaurantId: UUID,
        circleId: String,
        dishes: [DishItem]
    ) async throws {
        guard !dishes.isEmpty else { return }

        let visitsRef = db.collection("circles").document(circleId)
            .collection("restaurants").document(restaurantId.uuidString)
            .collection("visits")

        let snapshot = try await visitsRef
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let latest = snapshot.documents.first else {
            print("[Visit] no existing visits to patch for restaurant \(restaurantId)")
            return
        }

        // Merge with the visit's existing dish list, dedup-by-name, so a
        // double-tap or re-open doesn't create duplicates on the wire.
        let existing = (latest.data()["dishes"] as? [[String: Any]]) ?? []
        let existingNames = Set(existing.compactMap { ($0["name"] as? String)?.lowercased() })

        let newPayload: [[String: Any]] = dishes.compactMap { dish in
            guard !existingNames.contains(dish.name.lowercased()) else { return nil }
            var d: [String: Any] = ["name": dish.name, "liked": dish.liked]
            if let verdict = dish.verdict {
                d["verdict"] = verdict.rawValue
            }
            return d
        }
        guard !newPayload.isEmpty else { return }

        try await latest.reference.updateData([
            "dishes": existing + newPayload,
            "updatedAt": Date()
        ])
    }

    /// Fetch the full visit history for a restaurant, newest first.
    /// Returned as raw dictionaries — keep the wire format flexible since
    /// the shape of a Visit may grow (photos, who-you-were-with, etc.).
    func getVisits(restaurantId: UUID, circleId: String) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("circles").document(circleId)
                .collection("restaurants").document(restaurantId.uuidString)
                .collection("visits")
                .order(by: "date", descending: true)
                .getDocuments()
            return snapshot.documents.map { doc in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }
        } catch {
            print("Error fetching visits: \(error)")
            return []
        }
    }

    // MARK: - Dish Opinions

    struct DishOpinion: Codable, Identifiable {
        var id: String { "\(userId)_\(dishName)" }
        var userId: String
        var userName: String
        var restaurantId: String
        var restaurantName: String
        var dishName: String
        var liked: Bool
        var updatedAt: Date
    }

    struct AggregatedDishOpinion: Identifiable {
        var id: String { dishName }
        var dishName: String
        var likedBy: [String]     // display names
        var dislikedBy: [String]  // display names
        var likedCount: Int { likedBy.count }
        var dislikedCount: Int { dislikedBy.count }
    }

    /// Save a dish opinion for the current user in the circle
    func saveDishOpinion(
        dishName: String,
        liked: Bool,
        restaurantId: String,
        restaurantName: String,
        circleId: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let displayName = Auth.auth().currentUser?.displayName ?? "User"

        let docId = "\(uid)_\(dishName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let data: [String: Any] = [
            "userId": uid,
            "userName": displayName,
            "restaurantId": restaurantId,
            "restaurantName": restaurantName,
            "dishName": dishName,
            "liked": liked,
            "updatedAt": Date()
        ]

        try await db.collection("circles").document(circleId)
            .collection("dishOpinions").document(docId)
            .setData(data, merge: true)
    }

    /// Remove a dish opinion (when user deletes a dish)
    func removeDishOpinion(
        dishName: String,
        circleId: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let docId = "\(uid)_\(dishName.lowercased().replacingOccurrences(of: " ", with: "_"))"

        try await db.collection("circles").document(circleId)
            .collection("dishOpinions").document(docId)
            .delete()
    }

    /// Get all dish opinions for a specific restaurant in the circle
    func getDishOpinions(restaurantName: String, circleId: String) async -> [DishOpinion] {
        do {
            let snapshot = try await db.collection("circles").document(circleId)
                .collection("dishOpinions")
                .whereField("restaurantName", isEqualTo: restaurantName)
                .getDocuments()

            return snapshot.documents.compactMap { doc -> DishOpinion? in
                let data = doc.data()
                guard let userId = data["userId"] as? String,
                      let dishName = data["dishName"] as? String,
                      let liked = data["liked"] as? Bool else { return nil }

                return DishOpinion(
                    userId: userId,
                    userName: data["userName"] as? String ?? "Unknown",
                    restaurantId: data["restaurantId"] as? String ?? "",
                    restaurantName: data["restaurantName"] as? String ?? "",
                    dishName: dishName,
                    liked: liked,
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        } catch {
            print("Error fetching dish opinions: \(error)")
            return []
        }
    }

    /// Get aggregated dish opinions for a restaurant — grouped by dish name
    func getAggregatedOpinions(restaurantName: String, circleId: String) async -> [AggregatedDishOpinion] {
        let opinions = await getDishOpinions(restaurantName: restaurantName, circleId: circleId)
        let currentUid = Auth.auth().currentUser?.uid

        // Group by dish name (case-insensitive)
        var grouped: [String: (liked: [String], disliked: [String])] = [:]
        for opinion in opinions {
            // Skip current user's own opinions from the aggregation display
            if opinion.userId == currentUid { continue }

            let key = opinion.dishName.lowercased()
            if grouped[key] == nil {
                grouped[key] = (liked: [], disliked: [])
            }
            if opinion.liked {
                grouped[key]!.liked.append(opinion.userName)
            } else {
                grouped[key]!.disliked.append(opinion.userName)
            }
        }

        return grouped.map { key, value in
            // Use the original casing from the first opinion that matches
            let originalName = opinions.first { $0.dishName.lowercased() == key }?.dishName ?? key
            return AggregatedDishOpinion(
                dishName: originalName,
                likedBy: value.liked,
                dislikedBy: value.disliked
            )
        }.sorted { $0.likedCount + $0.dislikedCount > $1.likedCount + $1.dislikedCount }
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no ambiguous chars (0/O, 1/I)
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    enum CircleError: LocalizedError {
        case invalidCode
        case alreadyMember
        case requestAlreadyPending

        var errorDescription: String? {
            switch self {
            case .invalidCode: return "Invalid invite code. Check the code and try again."
            case .alreadyMember: return "You're already at this table!"
            case .requestAlreadyPending: return "You've already sent a request to join this table."
            }
        }
    }
}

// MARK: - Shared Restaurant (from Firestore)

struct SharedRestaurant: Identifiable {
    var id: String
    var userId: String
    var userName: String = "" // populated after fetch
    var name: String
    var address: String
    var cuisine: CuisineType
    var rating: Int
    var notes: String
    var dishes: [DishItem]
    var visitCount: Int
    var dateVisited: Date?
    var latitude: Double?
    var longitude: Double?

    var likedDishes: [DishItem] { dishes.filter { $0.liked } }
    var dislikedDishes: [DishItem] { dishes.filter { !$0.liked } }
    var hasCoordinates: Bool { latitude != nil && longitude != nil }
}
