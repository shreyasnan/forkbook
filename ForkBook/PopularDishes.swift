import Foundation

// MARK: - Popular Dishes by Cuisine Type
// Auto-suggested when a cuisine is detected, so the user only needs to thumbs up/down

struct PopularDishes {
    /// Returns a curated list of popular dishes for a given cuisine type.
    /// These are shown as quick-tap suggestions so the user doesn't have to type.
    static func dishes(for cuisine: CuisineType) -> [String] {
        switch cuisine {
        case .japanese:
            return [
                "Sushi", "Sashimi", "Ramen", "Tempura", "Gyoza",
                "Tonkatsu", "Udon", "Edamame", "Miso Soup", "Teriyaki Chicken",
                "Yakitori", "Katsu Curry", "California Roll", "Matcha Ice Cream"
            ]
        case .korean:
            return [
                "Bibimbap", "Korean BBQ", "Bulgogi", "Japchae", "Kimchi Jjigae",
                "Tteokbokki", "Korean Fried Chicken", "Samgyeopsal", "Kimchi",
                "Galbi", "Sundubu Jjigae", "Kimbap", "Pajeon"
            ]
        case .chinese:
            return [
                "Kung Pao Chicken", "Dim Sum", "Peking Duck", "Fried Rice",
                "Mapo Tofu", "Dumplings", "Hot Pot", "Spring Rolls",
                "Sweet and Sour Pork", "Dan Dan Noodles", "Char Siu",
                "Wonton Soup", "Chow Mein", "Xiao Long Bao"
            ]
        case .vietnamese:
            return [
                "Pho", "Banh Mi", "Spring Rolls", "Bun Bo Hue",
                "Banh Xeo", "Com Tam", "Goi Cuon", "Cao Lau",
                "Vietnamese Coffee", "Bun Cha", "Mi Quang"
            ]
        case .thai:
            return [
                "Pad Thai", "Green Curry", "Tom Yum", "Massaman Curry",
                "Papaya Salad", "Pad See Ew", "Mango Sticky Rice",
                "Tom Kha Gai", "Red Curry", "Thai Iced Tea",
                "Larb", "Khao Soi", "Satay"
            ]
        case .indian:
            return [
                "Butter Chicken", "Naan", "Biryani", "Tikka Masala",
                "Samosa", "Palak Paneer", "Dal Makhani", "Tandoori Chicken",
                "Gulab Jamun", "Garlic Naan", "Chana Masala",
                "Mango Lassi", "Vindaloo", "Raita"
            ]
        case .italian:
            return [
                "Margherita Pizza", "Pasta Carbonara", "Risotto", "Bruschetta",
                "Tiramisu", "Lasagna", "Osso Buco", "Caprese Salad",
                "Gnocchi", "Panna Cotta", "Bolognese", "Arancini",
                "Prosciutto e Melone", "Gelato"
            ]
        case .french:
            return [
                "Croissant", "Steak Frites", "Coq au Vin", "Crème Brûlée",
                "French Onion Soup", "Ratatouille", "Duck Confit",
                "Bouillabaisse", "Crêpes", "Escargot", "Quiche",
                "Soufflé", "Beef Bourguignon"
            ]
        case .mexican:
            return [
                "Tacos", "Burrito", "Guacamole", "Enchiladas",
                "Quesadilla", "Churros", "Elote", "Pozole",
                "Tamales", "Mole", "Ceviche", "Chips & Salsa",
                "Carnitas", "Horchata"
            ]
        case .mediterranean:
            return [
                "Hummus", "Falafel", "Shawarma", "Kebab",
                "Tabbouleh", "Pita Bread", "Baba Ganoush", "Greek Salad",
                "Moussaka", "Baklava", "Dolma", "Fattoush", "Labneh"
            ]
        case .american:
            return [
                "Burger", "Mac and Cheese", "BBQ Ribs", "Fried Chicken",
                "Steak", "Wings", "Fries", "Clam Chowder",
                "Pancakes", "Coleslaw", "Onion Rings", "Milkshake",
                "Pulled Pork", "Caesar Salad"
            ]
        case .other:
            return []
        }
    }
}
