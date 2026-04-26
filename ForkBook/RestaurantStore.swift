import Foundation
import SwiftUI
import FirebaseAuth

// MARK: - Persistence & State Management

@MainActor
class RestaurantStore: ObservableObject {
    @Published var restaurants: [Restaurant] = []

    private let saveKey = "ForkBookRestaurants"

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ restaurant: Restaurant) {
        restaurants.append(restaurant)
        save()
        syncOne(restaurant)
        resolvePlaceIdIfNeeded(for: restaurant.id)
    }

    func update(_ restaurant: Restaurant) {
        if let index = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[index] = restaurant
            save()
            syncOne(restaurants[index])
            resolvePlaceIdIfNeeded(for: restaurant.id)
        }
    }

    func delete(_ restaurant: Restaurant) {
        restaurants.removeAll { $0.id == restaurant.id }
        save()
        // Note: we intentionally don't delete the Firestore doc — circle
        // history is shared/append-flavored, and the UI treats the local
        // store as the source of truth for "what I see". A dedicated
        // un-share flow would remove the remote doc explicitly.
    }

    func delete(at offsets: IndexSet, in list: [Restaurant]) {
        let idsToDelete = offsets.map { list[$0].id }
        restaurants.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    /// Quick-add a restaurant with minimal info — auto-detects cuisine, sets defaults.
    /// Returns the created restaurant.
    @discardableResult
    func addQuick(
        name: String,
        address: String = "",
        category: RestaurantCategory
    ) -> Restaurant {
        let cuisine = CuisineDetector.detect(name: name, subtitle: address) ?? .other
        let restaurant = Restaurant(
            name: name,
            address: address,
            cuisine: cuisine,
            category: category,
            dateVisited: category == .visited ? Date() : nil
        )
        restaurants.append(restaurant)
        save()
        syncOne(restaurant)
        resolvePlaceIdIfNeeded(for: restaurant.id)
        return restaurant
    }

    func incrementVisitCount(for restaurant: Restaurant) {
        if let index = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[index].visitCount += 1
            restaurants[index].dateVisited = Date()
            save()
            syncOne(restaurants[index])
        }
    }

    // MARK: - Filtered Lists

    var visitedRestaurants: [Restaurant] {
        restaurants
            .filter { $0.category == .visited }
            .sorted { ($0.dateVisited ?? $0.dateAdded) > ($1.dateVisited ?? $1.dateAdded) }
    }

    var plannedRestaurants: [Restaurant] {
        restaurants
            .filter { $0.category == .planned }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var savedRestaurants: [Restaurant] {
        restaurants
            .filter { $0.category == .saved }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    /// Legacy alias
    var wishlistRestaurants: [Restaurant] { savedRestaurants }

    /// Regulars: visited 3+ times, reaction loved or liked
    var regularRestaurants: [Restaurant] {
        visitedRestaurants
            .filter { $0.visitCount >= 3 || $0.reaction == .loved }
            .sorted { $0.visitCount > $1.visitCount }
    }

    /// Go-to places: user-declared only
    var goToRestaurants: [Restaurant] {
        visitedRestaurants
            .filter { $0.isGoTo }
            .sorted { $0.visitCount > $1.visitCount }
    }

    /// Visited sorted by relationship: go-tos first, then loved, then liked, then rest
    var visitedByRelationship: [Restaurant] {
        visitedRestaurants.sorted { a, b in
            func tier(_ r: Restaurant) -> Int {
                if r.isGoTo { return 0 }
                if r.reaction == .loved && r.visitCount >= 2 { return 1 }
                if r.reaction == .loved { return 2 }
                if r.reaction == .liked && r.visitCount >= 2 { return 3 }
                if r.reaction == .liked { return 4 }
                return 5
            }
            let ta = tier(a), tb = tier(b)
            if ta != tb { return ta < tb }
            return (a.dateVisited ?? a.dateAdded) > (b.dateVisited ?? b.dateAdded)
        }
    }

    func markAsGoTo(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].isGoTo = true
            restaurants[i].goToNudgeShown = true
            save()
            syncOne(restaurants[i])
        }
    }

    func removeGoTo(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].isGoTo = false
            save()
            syncOne(restaurants[i])
        }
    }

    func markGoToNudgeShown(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].goToNudgeShown = true
            save()
            syncOne(restaurants[i])
        }
    }

    /// Quick-log a repeat visit: same reaction as last time, bump count.
    func quickLog(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].visitCount += 1
            restaurants[i].dateVisited = Date()
            save()
            syncOne(restaurants[i])
        }
    }

    // MARK: - State Transitions

    func markAsPlanned(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .planned
            save()
            syncOne(restaurants[i])
        }
    }

    func markAsVisited(_ restaurant: Restaurant, reaction: Reaction? = nil) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .visited
            restaurants[i].dateVisited = Date()
            restaurants[i].visitCount += (restaurants[i].category == .visited ? 1 : 0)
            if let reaction { restaurants[i].reaction = reaction }
            save()
            syncOne(restaurants[i])
        }
    }

    func removeFromPlan(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .saved
            save()
            syncOne(restaurants[i])
        }
    }

    // MARK: - Sharing

    func shareText(for category: RestaurantCategory) -> String {
        let list = category == .visited ? visitedRestaurants : wishlistRestaurants
        let title = category == .visited ? "🍽 My Restaurants" : "📋 My Wishlist"

        guard !list.isEmpty else {
            return "\(title)\n\nNo restaurants yet!"
        }

        var text = "\(title)\n\n"
        for r in list {
            text += "• \(r.name)"
            if r.cuisine != .other {
                text += " (\(r.cuisine.rawValue))"
            }
            if let reaction = r.reaction {
                text += " — \(reaction.emoji) \(reaction.rawValue)"
            } else if r.rating >= 5 {
                text += " — ❤️ Loved"
            } else if r.rating >= 3 {
                text += " — 👍 Liked"
            }
            if !r.address.isEmpty {
                text += "\n  📍 \(r.address)"
            }
            if r.visitCount > 1 {
                text += "\n  🔄 Visited \(r.visitCount) times"
            }
            if let dateStr = r.dateVisitedFormatted {
                text += "\n  📅 Last visited \(dateStr)"
            }
            if !r.recommendedBy.isEmpty {
                text += "\n  rec'd by \(r.recommendedBy)"
            }
            if !r.likedDishes.isEmpty {
                text += "\n  👍 " + r.likedDishes.map(\.name).joined(separator: ", ")
            }
            if !r.dislikedDishes.isEmpty {
                text += "\n  👎 " + r.dislikedDishes.map(\.name).joined(separator: ", ")
            }
            if !r.notes.isEmpty {
                text += "\n  \(r.notes)"
            }
            text += "\n"
        }
        text += "\nShared from ForkBook"
        return text
    }

    // MARK: - Firestore Import (one-time sync down)

    /// Reconcile local with Firestore. Firestore is the source of truth:
    ///   - Imports restaurants present in Firestore but missing locally.
    ///   - REMOVES restaurants present locally but missing in Firestore
    ///     (covers cleanup-script deletes, deletions from other devices,
    ///     and stale UserDefaults restored from iCloud after reinstall).
    /// Runs only when we successfully obtained a circle — a network or
    /// auth failure short-circuits before the reconciliation, so we
    /// don't wipe local data on transient errors.
    func importFromFirestore(prefetchedRestaurants: [SharedRestaurant]? = nil) async {
        let uid = FirebaseAuth.Auth.auth().currentUser?.uid

        let remote: [SharedRestaurant]
        if let prefetched = prefetchedRestaurants {
            remote = prefetched
        } else {
            let circles = await FirestoreService.shared.getMyCircles()
            guard let circle = circles.first else { return }
            remote = await FirestoreService.shared.getCircleRestaurants(circleId: circle.id)
        }

        let myRemote = remote.filter { $0.userId == uid }
        let remoteNames = Set(myRemote.map { $0.name.lowercased() })
        let existingNames = Set(restaurants.map { $0.name.lowercased() })

        // Remove locals that are no longer in Firestore. This is the
        // step that lets `cleanup_my_places.py` deletes propagate, and
        // that fixes the "iCloud restored 200 stale UserDefaults
        // entries on reinstall" failure mode. Match by lowercased
        // name — same key used everywhere else in this codebase.
        let beforeCount = restaurants.count
        restaurants.removeAll { r in !remoteNames.contains(r.name.lowercased()) }
        let removed = beforeCount - restaurants.count

        // Import remotes that are missing locally.
        var imported = 0
        for r in myRemote {
            if existingNames.contains(r.name.lowercased()) { continue }
            let restaurant = Restaurant(
                name: r.name,
                address: r.address,
                cuisine: r.cuisine,
                category: .visited,
                rating: r.rating,
                notes: r.notes,
                dishes: r.dishes,
                dateVisited: r.dateVisited,
                visitCount: r.visitCount,
                reaction: r.rating >= 5 ? .loved : (r.rating >= 3 ? .liked : .meh)
            )
            restaurants.append(restaurant)
            imported += 1
        }

        if imported > 0 || removed > 0 {
            save()
            print("Synced from Firestore: imported \(imported), removed \(removed)")
        }
    }

    // MARK: - Google Place ID Resolution
    //
    // Apple's MapKit picker doesn't expose Google Place IDs, so we fetch
    // one ourselves after the restaurant is saved. Runs in the background;
    // UI never waits on it. If it fails (no API key, no network, low
    // confidence), the record just stays as it was — the nightly backfill
    // script will eventually catch it.

    func resolvePlaceIdIfNeeded(for id: UUID) {
        guard let index = restaurants.firstIndex(where: { $0.id == id }) else { return }
        let restaurant = restaurants[index]
        // Skip if we already have a confident Place ID.
        if let existing = restaurant.googlePlaceId, !existing.isEmpty { return }

        let name = restaurant.name
        let city = restaurant.city
        let lat = restaurant.latitude
        let lng = restaurant.longitude

        Task { [weak self] in
            guard let self else { return }
            let match = await PlacesResolver.shared.resolve(
                name: name,
                city: city,
                lat: lat,
                lng: lng
            )
            guard let match else {
                print("[PlacesResolver] no match for '\(name)' (\(city))")
                return
            }
            // Re-find the restaurant — index may have shifted since the
            // async call kicked off.
            guard let freshIndex = self.restaurants.firstIndex(where: { $0.id == id }) else {
                return
            }
            // Don't clobber a manual edit the user made in the meantime.
            if let existing = self.restaurants[freshIndex].googlePlaceId, !existing.isEmpty {
                return
            }
            self.restaurants[freshIndex].googlePlaceId = match.placeId
            // Backfill lat/lng from the Places response if the record
            // didn't have them — improves future menu lookups.
            if self.restaurants[freshIndex].latitude == nil, let mlat = match.lat {
                self.restaurants[freshIndex].latitude = mlat
            }
            if self.restaurants[freshIndex].longitude == nil, let mlng = match.lng {
                self.restaurants[freshIndex].longitude = mlng
            }
            self.save()
            // Push the now-resolved Place ID (and any lat/lng backfill) up
            // to Firestore so this device doesn't have to re-resolve it
            // after a reinstall, and so circle members see the same
            // metadata.
            self.syncOne(self.restaurants[freshIndex])
            print(
                "[PlacesResolver] '\(name)' → \(match.matchedName) "
                + "(conf=\(match.confidence), \(match.status.rawValue))"
            )
            // Warm the menu cache now that we have a Place ID — next time
            // the user opens the dish picker for this place, chips will
            // render from cache instead of a cold fetch.
            MenuDataService.shared.prefetch(placeId: match.placeId)
        }
    }

    /// Walk local restaurants and fetch a Place ID for any that lack one.
    /// Useful on first launch after this feature ships — running it from
    /// `ContentView.onAppear` once populates the whole store in the
    /// background.
    func resolvePlaceIdsForAllMissing() {
        let ids = restaurants.filter {
            ($0.googlePlaceId ?? "").isEmpty
        }.map(\.id)
        for id in ids {
            resolvePlaceIdIfNeeded(for: id)
        }
    }

    // MARK: - Persistence (UserDefaults for simplicity)

    private func save() {
        if let data = try? JSONEncoder().encode(restaurants) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Restaurant].self, from: data) {
            restaurants = decoded
        }
    }

    // MARK: - Firestore Push (fire-and-forget)
    //
    // Every local mutation (add/update/visit/go-to toggle/etc.) flows
    // through `syncOne`. If we already know the user's primary circle —
    // populated as a side effect of `getMyCircles()` — we push immediately
    // in a detached Task so UI doesn't wait. If we don't know the circle
    // yet (first launch, not signed in, offline), we silently skip; the
    // next write on the same record will catch it up because `setData`
    // uses merge:true with the restaurant's stable UUID as the doc ID.
    //
    // Network failures are logged but non-fatal — UserDefaults remains
    // the source of truth, and the next successful write reconciles
    // whatever drifted.
    private func syncOne(_ restaurant: Restaurant) {
        let circleId = FirestoreService.shared.primaryCircleId
        guard let circleId, !circleId.isEmpty else { return }
        Task {
            do {
                try await FirestoreService.shared.syncRestaurant(
                    restaurant,
                    circleId: circleId
                )
            } catch {
                print("[Sync] failed to push '\(restaurant.name)': \(error)")
            }
        }
    }

    /// Back-fill sync: push every local restaurant. Called once the primary
    /// circle ID becomes known (e.g. after first successful circle fetch on
    /// app launch) so records created before sign-in eventually reach the
    /// cloud without the user having to open each one.
    func syncAllToFirestore() {
        let circleId = FirestoreService.shared.primaryCircleId
        guard let circleId, !circleId.isEmpty else { return }
        let snapshot = restaurants
        Task {
            for r in snapshot {
                do {
                    try await FirestoreService.shared.syncRestaurant(r, circleId: circleId)
                } catch {
                    print("[Sync] backfill failed for '\(r.name)': \(error)")
                }
            }
        }
    }
}
