import Foundation
import FirebaseFirestore

// MARK: - MenuDataService
//
// Fetches restaurant menu data from the Firestore "menus" collection.
// Provides dish lookups for:
// - Search results: show real dishes for matched restaurants
// - "I went here" logging: pre-populate dish checklist from actual menu
//
// Caches results in memory so repeated lookups are instant.
// Individual restaurants are fetched on demand, not all at once.

@MainActor
final class MenuDataService: ObservableObject {
    static let shared = MenuDataService()

    private var db: Firestore { FirebaseConfig.shared.db }
    private var cache: [String: MenuRestaurant] = [:]  // keyed by lowercased name

    private init() {}

    // MARK: - Public API

    /// Fetch dishes for a restaurant by name. Returns cached result if available.
    func dishes(for restaurantName: String) async -> [MenuDish] {
        let key = restaurantName.lowercased().trimmingCharacters(in: .whitespaces)

        // Check cache (exact)
        if let cached = cache[key] {
            return cached.dishes
        }

        // Check cache (partial match)
        for (name, restaurant) in cache {
            if name.contains(key) || key.contains(name) {
                return restaurant.dishes
            }
        }

        // Fetch from Firestore
        return await fetchFromFirestore(name: restaurantName, key: key)
    }

    /// Get top N dishes, sorted by price descending (mains first).
    func topDishes(for restaurantName: String, limit: Int = 8) async -> [MenuDish] {
        let all = await dishes(for: restaurantName)
        return Array(all.prefix(limit))
    }

    /// Get dish names only (for the "I went here" checklist).
    func dishNames(for restaurantName: String, limit: Int = 15) async -> [String] {
        let all = await topDishes(for: restaurantName, limit: limit)
        return all.map(\.name)
    }

    /// Check if we have menu data cached (non-async, for quick UI checks).
    func hasCachedMenu(for restaurantName: String) -> Bool {
        let key = restaurantName.lowercased().trimmingCharacters(in: .whitespaces)
        if cache[key] != nil { return true }
        for name in cache.keys {
            if name.contains(key) || key.contains(name) { return true }
        }
        return false
    }

    /// Get cached dishes synchronously (returns empty if not yet fetched).
    func cachedDishes(for restaurantName: String) -> [MenuDish] {
        let key = restaurantName.lowercased().trimmingCharacters(in: .whitespaces)
        if let cached = cache[key] { return cached.dishes }
        for (name, restaurant) in cache {
            if name.contains(key) || key.contains(name) { return restaurant.dishes }
        }
        return []
    }

    // MARK: - Firestore Fetch

    private func fetchFromFirestore(name: String, key: String) async -> [MenuDish] {
        do {
            // Try exact match on nameLower field
            let snapshot = try await db.collection("menus")
                .whereField("nameLower", isEqualTo: key)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                let restaurant = parseDocument(doc)
                cache[key] = restaurant
                return restaurant.dishes
            }

            // No exact match — try slug-based doc ID lookup
            let slug = key
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                .prefix(60)

            let docRef = db.collection("menus").document(String(slug))
            let docSnap = try await docRef.getDocument()

            if docSnap.exists {
                let restaurant = parseDocument(docSnap)
                cache[key] = restaurant
                return restaurant.dishes
            }

            // Cache the miss too (empty) to avoid repeated queries
            cache[key] = MenuRestaurant(name: name, cuisine: "", city: "", dishes: [])
            return []

        } catch {
            print("[MenuDataService] Firestore error for '\(name)': \(error.localizedDescription)")
            return []
        }
    }

    private func parseDocument(_ doc: DocumentSnapshot) -> MenuRestaurant {
        let data = doc.data() ?? [:]
        let name = data["name"] as? String ?? ""
        let cuisine = data["cuisine"] as? String ?? ""
        let city = data["city"] as? String ?? ""

        let rawDishes = data["dishes"] as? [[String: Any]] ?? []
        let dishes = rawDishes.compactMap { d -> MenuDish? in
            guard let dishName = d["name"] as? String, !dishName.isEmpty else { return nil }
            return MenuDish(
                name: dishName,
                description: d["desc"] as? String,
                price: d["price"] as? Double ?? 0
            )
        }

        return MenuRestaurant(name: name, cuisine: cuisine, city: city, dishes: dishes)
    }

    private func parseDocument(_ doc: QueryDocumentSnapshot) -> MenuRestaurant {
        let data = doc.data()
        let name = data["name"] as? String ?? ""
        let cuisine = data["cuisine"] as? String ?? ""
        let city = data["city"] as? String ?? ""

        let rawDishes = data["dishes"] as? [[String: Any]] ?? []
        let dishes = rawDishes.compactMap { d -> MenuDish? in
            guard let dishName = d["name"] as? String, !dishName.isEmpty else { return nil }
            return MenuDish(
                name: dishName,
                description: d["desc"] as? String,
                price: d["price"] as? Double ?? 0
            )
        }

        return MenuRestaurant(name: name, cuisine: cuisine, city: city, dishes: dishes)
    }
}

// MARK: - Models

struct MenuDish {
    let name: String
    let description: String?
    let price: Double
}

struct MenuRestaurant {
    let name: String
    let cuisine: String
    let city: String
    let dishes: [MenuDish]
}
