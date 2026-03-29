import Foundation

// MARK: - Data Models

enum RestaurantCategory: String, Codable, CaseIterable, Identifiable {
    case visited = "Visited"
    case wishlist = "Wishlist"

    var id: String { rawValue }
}

enum CuisineType: String, Codable, CaseIterable, Identifiable {
    case american = "American"
    case chinese = "Chinese"
    case french = "French"
    case indian = "Indian"
    case italian = "Italian"
    case japanese = "Japanese"
    case korean = "Korean"
    case mediterranean = "Mediterranean"
    case mexican = "Mexican"
    case thai = "Thai"
    case vietnamese = "Vietnamese"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Dish Item (liked or disliked)

struct DishItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var liked: Bool  // true = liked, false = disliked

    init(id: UUID = UUID(), name: String, liked: Bool = true) {
        self.id = id
        self.name = name
        self.liked = liked
    }
}

// MARK: - Restaurant

struct Restaurant: Identifiable, Codable {
    var id: UUID
    var name: String
    var address: String      // address or area from autocomplete
    var cuisine: CuisineType
    var category: RestaurantCategory
    var rating: Int          // 1-5 stars (0 = unrated, used for wishlist)
    var notes: String
    var recommendedBy: String // who recommended it (wishlist)
    var dishes: [DishItem]   // liked and disliked dishes
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        address: String = "",
        cuisine: CuisineType = .other,
        category: RestaurantCategory = .visited,
        rating: Int = 0,
        notes: String = "",
        recommendedBy: String = "",
        dishes: [DishItem] = [],
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.cuisine = cuisine
        self.category = category
        self.rating = rating
        self.notes = notes
        self.recommendedBy = recommendedBy
        self.dishes = dishes
        self.dateAdded = dateAdded
    }

    var likedDishes: [DishItem] { dishes.filter { $0.liked } }
    var dislikedDishes: [DishItem] { dishes.filter { !$0.liked } }
}
