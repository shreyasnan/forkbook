import Foundation
import FirebaseAuth
import FirebaseFunctions

// MARK: - Ask ForkBook Service

@MainActor
class AskForkBookService: ObservableObject {
    static let shared = AskForkBookService()

    @Published var isLoading = false
    @Published var lastAnswer: ForkBookAnswer?
    @Published var error: String?

    private lazy var functions = Functions.functions()

    struct ForkBookAnswer {
        let text: String
        let suggestions: [Suggestion]
    }

    struct Suggestion {
        let name: String
        let reason: String
    }

    private init() {}

    // MARK: - Ask

    func ask(
        question: String,
        myRestaurants: [Restaurant],
        tableRestaurants: [SharedRestaurant],
        members: [FirestoreService.CircleMember],
        tastePrefs: TastePreferences
    ) async {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard Auth.auth().currentUser != nil else {
            error = "Please sign in first"
            return
        }

        isLoading = true
        error = nil

        // Build context payload
        let context = buildContext(
            myRestaurants: myRestaurants,
            tableRestaurants: tableRestaurants,
            members: members,
            tastePrefs: tastePrefs
        )

        let data: [String: Any] = [
            "question": question,
            "context": context
        ]

        do {
            let result = try await functions.httpsCallable("askForkBook").call(data)

            if let response = result.data as? [String: Any] {
                let answerText = response["answer"] as? String ?? "I'm not sure what to recommend right now."
                let rawSuggestions = response["suggestions"] as? [[String: Any]] ?? []

                let suggestions = rawSuggestions.compactMap { dict -> Suggestion? in
                    guard let name = dict["name"] as? String,
                          let reason = dict["reason"] as? String else { return nil }
                    return Suggestion(name: name, reason: reason)
                }

                lastAnswer = ForkBookAnswer(text: answerText, suggestions: suggestions)
            }
        } catch {
            self.error = "Couldn't get a recommendation right now. Try again!"
            print("AskForkBook error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Build Context

    private func buildContext(
        myRestaurants: [Restaurant],
        tableRestaurants: [SharedRestaurant],
        members: [FirestoreService.CircleMember],
        tastePrefs: TastePreferences
    ) -> [String: Any] {
        let userName = Auth.auth().currentUser?.displayName ?? "there"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        // My restaurants — rank by relationship strength first, then trim.
        // This keeps loved/go-to places in context even if they haven't been
        // visited recently (the prior recency-only sort dropped them).
        func myTier(_ r: Restaurant) -> Int {
            if r.isGoTo { return 0 }
            if r.reaction == .loved && r.visitCount >= 2 { return 1 }
            if r.reaction == .loved { return 2 }
            if r.reaction == .liked && r.visitCount >= 2 { return 3 }
            if r.reaction == .liked { return 4 }
            return 5
        }
        let myData: [[String: Any]] = myRestaurants
            .sorted { a, b in
                let ta = myTier(a), tb = myTier(b)
                if ta != tb { return ta < tb }
                return (a.dateVisited ?? .distantPast) > (b.dateVisited ?? .distantPast)
            }
            .prefix(30)
            .map { r in
                var dict: [String: Any] = [
                    "name": r.name,
                    "cuisine": r.cuisine.rawValue,
                    "reaction": r.reaction?.rawValue ?? "",
                    "isGoTo": r.isGoTo,
                    "visitCount": r.visitCount,
                ]
                if let date = r.dateVisited {
                    dict["dateVisited"] = dateFormatter.string(from: date)
                }
                if !r.address.isEmpty {
                    dict["city"] = r.city
                }
                if !r.dishes.isEmpty {
                    dict["dishes"] = r.dishes.map { [
                        "name": $0.name,
                        "liked": $0.liked
                    ] as [String: Any] }
                }
                if !r.occasionTags.isEmpty {
                    dict["occasions"] = r.occasionTags.map(\.rawValue)
                }
                return dict
            }

        // Table restaurants — rank by reaction strength + visit count first.
        // Loved/highly-rated picks from the table should never be trimmed out.
        func tableTier(_ r: SharedRestaurant) -> Int {
            if r.rating >= 5 && r.visitCount >= 2 { return 0 }
            if r.rating >= 5 { return 1 }
            if r.rating >= 4 && r.visitCount >= 2 { return 2 }
            if r.rating >= 4 { return 3 }
            return 4
        }
        let tableData: [[String: Any]] = tableRestaurants
            .sorted { a, b in
                let ta = tableTier(a), tb = tableTier(b)
                if ta != tb { return ta < tb }
                return (a.dateVisited ?? .distantPast) > (b.dateVisited ?? .distantPast)
            }
            .prefix(40)
            .map { r in
                var dict: [String: Any] = [
                    "name": r.name,
                    "cuisine": r.cuisine.rawValue,
                    "rating": r.rating,
                    "visitCount": r.visitCount,
                    "userName": r.userName.isEmpty ? "Friend" : r.userName,
                ]
                if let date = r.dateVisited {
                    dict["dateVisited"] = dateFormatter.string(from: date)
                }
                if !r.address.isEmpty {
                    let city = r.address.components(separatedBy: ",").dropFirst().first?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    if !city.isEmpty { dict["city"] = city }
                }
                if !r.likedDishes.isEmpty {
                    dict["dishes"] = r.likedDishes.map { ["name": $0.name] }
                }
                return dict
            }

        let memberData = members.map { ["name": $0.displayName.components(separatedBy: " ").first ?? $0.displayName] }

        var prefsData: [String: Any] = [:]
        if !tastePrefs.favoriteCuisines.isEmpty {
            prefsData["favoriteCuisines"] = tastePrefs.favoriteCuisines.map(\.rawValue)
        }
        if let freq = tastePrefs.diningFrequency {
            prefsData["diningFrequency"] = freq.rawValue
        }

        return [
            "userName": userName.components(separatedBy: " ").first ?? userName,
            "tastePrefs": prefsData,
            "myRestaurants": myData,
            "tableRestaurants": tableData,
            "members": memberData,
        ]
    }

    func clear() {
        lastAnswer = nil
        error = nil
    }
}
