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
    }

    func update(_ restaurant: Restaurant) {
        if let index = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[index] = restaurant
            save()
        }
    }

    func delete(_ restaurant: Restaurant) {
        restaurants.removeAll { $0.id == restaurant.id }
        save()
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
        return restaurant
    }

    func incrementVisitCount(for restaurant: Restaurant) {
        if let index = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[index].visitCount += 1
            restaurants[index].dateVisited = Date()
            save()
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
        }
    }

    func removeGoTo(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].isGoTo = false
            save()
        }
    }

    func markGoToNudgeShown(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].goToNudgeShown = true
            save()
        }
    }

    /// Quick-log a repeat visit: same reaction as last time, bump count.
    func quickLog(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].visitCount += 1
            restaurants[i].dateVisited = Date()
            save()
        }
    }

    // MARK: - State Transitions

    func markAsPlanned(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .planned
            save()
        }
    }

    func markAsVisited(_ restaurant: Restaurant, reaction: Reaction? = nil) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .visited
            restaurants[i].dateVisited = Date()
            restaurants[i].visitCount += (restaurants[i].category == .visited ? 1 : 0)
            if let reaction { restaurants[i].reaction = reaction }
            save()
        }
    }

    func removeFromPlan(_ restaurant: Restaurant) {
        if let i = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
            restaurants[i].category = .saved
            save()
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

    /// Pull the current user's restaurants from Firestore into local storage.
    /// Skips any that already exist locally (by name match).
    /// Import from Firestore. Accepts pre-fetched restaurants to avoid duplicate network calls.
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
        let existingNames = Set(restaurants.map { $0.name.lowercased() })
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

        if imported > 0 {
            save()
            print("Imported \(imported) restaurants from Firestore")
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
}
