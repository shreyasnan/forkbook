import Foundation

// MARK: - Restaurant Dish Database (auto-generated from Yelp)
// Re-generate by running: python3 Scripts/yelp_scraper.py

struct RestaurantDishDB {
    /// Lookup dishes by restaurant name (case-insensitive key)
    static let dishes: [String: [String]] = [
    ]

    /// Look up dishes for a restaurant name.
    /// Returns Yelp-sourced dishes if found, otherwise nil.
    static func lookup(_ name: String) -> [String]? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        // Exact match
        if let exact = dishes[key] {
            return exact
        }
        // Substring match (handles locations like 'Nobu Palo Alto')
        for (dbName, dbDishes) in dishes {
            if key.contains(dbName) || dbName.contains(key) {
                return dbDishes
            }
        }
        return nil
    }
}
