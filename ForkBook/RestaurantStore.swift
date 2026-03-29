import Foundation
import SwiftUI

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

    // MARK: - Filtered Lists

    var visitedRestaurants: [Restaurant] {
        restaurants
            .filter { $0.category == .visited }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var wishlistRestaurants: [Restaurant] {
        restaurants
            .filter { $0.category == .wishlist }
            .sorted { $0.dateAdded > $1.dateAdded }
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
            if r.rating > 0 {
                text += " — " + String(repeating: "⭐", count: r.rating)
            }
            if !r.address.isEmpty {
                text += "\n  📍 \(r.address)"
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
