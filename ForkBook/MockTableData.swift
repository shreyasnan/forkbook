import Foundation

// MARK: - Mock Table Data
//
// Seeds the "My Table" with 5 friends and ~10 restaurants each so the hero card
// has real signal diversity to prioritize across. Used only when the real
// circle comes back empty (first-run / no circle / solo mode).
//
// All dishes are vegetarian. Restaurant data and menu items are sourced from
// the bay_area_menus DB where possible.
//
// Friend archetypes are intentionally distinct to test taste-match and
// consensus signals, and several restaurants are shared across multiple
// friends so the hero card can demonstrate unanimous-love prioritization.

enum MockTableData {

    // MARK: - Friend profiles

    struct MockFriend {
        let uid: String
        let displayName: String
    }

    static let friends: [MockFriend] = [
        MockFriend(uid: "mock_pragya",  displayName: "Pragya"),         // Japanese / ramen / sushi
        MockFriend(uid: "mock_puneet",  displayName: "Puneet"),         // Indian food devotee
        MockFriend(uid: "mock_ankita",  displayName: "Ankita"),         // Italian / French / date-night
        MockFriend(uid: "mock_pratha",  displayName: "Pratha"),         // Chinese / East Asian / dim sum
        MockFriend(uid: "mock_jay",     displayName: "Jay"),            // Adventurous, tries everything
    ]

    // MARK: - Public API
    //
    // KILL SWITCH: when testing with real friends, mocks pollute the
    // UI with fake-Pragya data even after a real circle exists.
    // Setting this to `false` returns empty from both builders so
    // every call site stays valid but produces nothing. Flip back to
    // `true` only for solo dev / first-run UX testing where you want
    // signal diversity without onboarding a real circle.
    static let mockEnabled = false

    /// Build mock SharedRestaurant entries with relative dates anchored to now.
    static func buildSharedRestaurants() -> [SharedRestaurant] {
        guard mockEnabled else { return [] }
        let now = DebugClock.now
        func daysAgo(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: -n, to: now) ?? now }

        var result: [SharedRestaurant] = []

        // Helper to build an entry concisely
        func entry(
            _ uid: String,
            _ name: String,
            _ address: String,
            _ cuisine: CuisineType,
            rating: Int,
            dishes: [(String, Bool)] = [],  // (name, liked)
            visitCount: Int = 1,
            daysSinceVisit: Int,
            lat: Double? = nil,
            lng: Double? = nil
        ) -> SharedRestaurant {
            SharedRestaurant(
                id: "\(uid)_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                userId: uid,
                userName: friends.first { $0.uid == uid }?.displayName ?? "Friend",
                name: name,
                address: address,
                cuisine: cuisine,
                rating: rating,
                notes: "",
                dishes: dishes.map { DishItem(name: $0.0, liked: $0.1) },
                visitCount: visitCount,
                dateVisited: daysAgo(daysSinceVisit),
                latitude: lat,
                longitude: lng
            )
        }

        // =================================================================
        // MARK: Pragya — Japanese / ramen / sushi
        // =================================================================

        result.append(entry("mock_pragya", "Shizen", "370 14th St, San Francisco", .japanese,
            rating: 5, dishes: [("Spicy Garlic Miso Ramen", true), ("Agedashi Tofu", true), ("Avocado Roll", true)],
            visitCount: 4, daysSinceVisit: 2, lat: 37.7679, lng: -122.4194))

        result.append(entry("mock_pragya", "Hinodeya Ramen", "1560 Fillmore St, San Francisco", .japanese,
            rating: 5, dishes: [("Creamy Ramen", true), ("Dashi Butter Corn", true), ("Edamame", true)],
            visitCount: 3, daysSinceVisit: 5, lat: 37.7835, lng: -122.4324))

        result.append(entry("mock_pragya", "Koo", "408 Irving St, San Francisco", .japanese,
            rating: 5, dishes: [("Crispy Tofu", true), ("Eggplant Dengaku", true), ("Marinated Artichoke", true)],
            visitCount: 2, daysSinceVisit: 8, lat: 37.7640, lng: -122.4636))

        result.append(entry("mock_pragya", "Kiki", "474 Geary St, San Francisco", .japanese,
            rating: 4, dishes: [("Edamame", true), ("Vegetable Tempura", true), ("Fried Tofu", true)],
            visitCount: 2, daysSinceVisit: 12, lat: 37.7869, lng: -122.4130))

        result.append(entry("mock_pragya", "Nippon Curry", "16 Turk St, San Francisco", .japanese,
            rating: 4, dishes: [("Pumpkin Croquette Curry", true), ("Potato Croquette Curry", true)],
            visitCount: 3, daysSinceVisit: 15, lat: 37.7840, lng: -122.4100))

        result.append(entry("mock_pragya", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 4, dishes: [("Masala Dosa", true)],
            daysSinceVisit: 21, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_pragya", "Tartine Manufactory", "595 Alabama St, San Francisco", .american,
            rating: 5, dishes: [("Morning Bun", true), ("Country Bread", true)],
            visitCount: 2, daysSinceVisit: 7, lat: 37.7644, lng: -122.4115))

        result.append(entry("mock_pragya", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 3, dishes: [("Moroccan Couscous", false)],
            daysSinceVisit: 40, lat: 37.7749, lng: -122.4376))

        result.append(entry("mock_pragya", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 4, dishes: [("Margherita Pizza", true)],
            daysSinceVisit: 25, lat: 37.7589, lng: -122.4120))

        result.append(entry("mock_pragya", "Burma Superstar", "309 Clement St, San Francisco", .other,
            rating: 4, dishes: [("Yellow Bean Tofu", true), ("Eggplant Curry", true)],
            daysSinceVisit: 32, lat: 37.7828, lng: -122.4630))

        // =================================================================
        // MARK: Puneet — Indian food devotee
        // =================================================================

        result.append(entry("mock_puneet", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 5, dishes: [("Masala Dosa", true), ("Filter Coffee", true), ("Idli Sambar", true)],
            visitCount: 5, daysSinceVisit: 2, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_puneet", "Dishoom", "1 Kearny St, San Francisco", .indian,
            rating: 5, dishes: [("Jackfruit Biryani", true), ("Gunpowder Potatoes", true), ("Bhel", true)],
            visitCount: 3, daysSinceVisit: 4, lat: 37.7900, lng: -122.4033))

        result.append(entry("mock_puneet", "Masala Dosa", "981 Valencia St, San Francisco", .indian,
            rating: 5, dishes: [("Aloo Gobi", true), ("Bhindi Masala", true), ("Baigan Bharta", true)],
            visitCount: 4, daysSinceVisit: 6, lat: 37.7575, lng: -122.4212))

        result.append(entry("mock_puneet", "Chaat Corner", "55 E 3rd Ave, San Mateo", .indian,
            rating: 5, dishes: [("Achari Paneer", true), ("Aloo Tikki Chaat", true), ("Bhel Puri", true), ("Butter Paneer", true)],
            visitCount: 3, daysSinceVisit: 8, lat: 37.5633, lng: -122.3232))

        result.append(entry("mock_puneet", "Kasa", "4001 18th St, San Francisco", .indian,
            rating: 4, dishes: [("Paneer Tikka Kati Roll", true), ("Garlic Naan", true), ("Dal Makhani", true)],
            visitCount: 2, daysSinceVisit: 11, lat: 37.7610, lng: -122.4353))

        result.append(entry("mock_puneet", "Jaipur Cuisine", "2040 Polk St, San Francisco", .indian,
            rating: 4, dishes: [("Aloo Gobhi", true), ("Chatpati Bhindi", true), ("Dal Tadka", true)],
            visitCount: 2, daysSinceVisit: 16, lat: 37.7960, lng: -122.4220))

        result.append(entry("mock_puneet", "Chaat Bhavan Express", "5765 Jarvis Ave, Newark", .indian,
            rating: 4, dishes: [("Pav Bhaji", true), ("Ragada Pattice", true), ("Aloo Tikki Chana", true)],
            daysSinceVisit: 20, lat: 37.5274, lng: -122.0395))

        result.append(entry("mock_puneet", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 4, dishes: [("Margherita Pizza", true), ("Burrata", true)],
            daysSinceVisit: 14, lat: 37.7589, lng: -122.4120))

        result.append(entry("mock_puneet", "Shizen", "370 14th St, San Francisco", .japanese,
            rating: 5, dishes: [("Shiitake Maki", true), ("Avocado Roll", true)],
            daysSinceVisit: 18, lat: 37.7679, lng: -122.4194))

        result.append(entry("mock_puneet", "Laughing Buddha", "1413 Clement St, San Francisco", .chinese,
            rating: 4, dishes: [("Kung Pao Tofu", true)],
            daysSinceVisit: 30, lat: 37.7828, lng: -122.4645))

        // =================================================================
        // MARK: Ankita — Italian / French / date-night
        // =================================================================

        result.append(entry("mock_ankita", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 5, dishes: [("Margherita Pizza", true), ("Burrata", true), ("Cacio e Pepe", true)],
            visitCount: 4, daysSinceVisit: 3, lat: 37.7589, lng: -122.4120))

        result.append(entry("mock_ankita", "Delfina", "3621 18th St, San Francisco", .italian,
            rating: 5, dishes: [("Spaghetti Pomodoro", true), ("Tiramisu", true)],
            visitCount: 3, daysSinceVisit: 7, lat: 37.7615, lng: -122.4244))

        result.append(entry("mock_ankita", "Chouchou", "400 Dewey Blvd, San Francisco", .french,
            rating: 5, dishes: [("Baked Brie", true), ("Ratatouille", true), ("Chocolate Mousse", true)],
            visitCount: 2, daysSinceVisit: 9, lat: 37.7444, lng: -122.4642))

        result.append(entry("mock_ankita", "Frascati", "1901 Hyde St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Fresh Fettuccini", true), ("Burrata", true), ("Panna Cotta", true)],
            visitCount: 3, daysSinceVisit: 11, lat: 37.7939, lng: -122.4185))

        result.append(entry("mock_ankita", "a Mano", "2500 California St, San Francisco", .italian,
            rating: 5, dishes: [("Cacio e Pepe Fries", true), ("Kabocha Squash Ravioli", true), ("Arancini", true)],
            visitCount: 2, daysSinceVisit: 14, lat: 37.7877, lng: -122.4380))

        result.append(entry("mock_ankita", "Souvla", "517 Hayes St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Greek Salad", true), ("Feta Dip", true)],
            visitCount: 4, daysSinceVisit: 6, lat: 37.7765, lng: -122.4261))

        result.append(entry("mock_ankita", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Moroccan Couscous", true), ("Flatbread", true)],
            visitCount: 2, daysSinceVisit: 18, lat: 37.7749, lng: -122.4376))

        result.append(entry("mock_ankita", "Starbelly", "3583 16th St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Baked Eggs", true), ("Brown Butter Cornbread", true), ("Cheesecake Panna Cotta", true)],
            visitCount: 2, daysSinceVisit: 22, lat: 37.7641, lng: -122.4318))

        result.append(entry("mock_ankita", "Florentine Trattoria", "1801 Union St, San Francisco", .italian,
            rating: 4, dishes: [("Eggplant Parmigiana", true), ("Gnocchi Margherita", true), ("Spinach Ravioli", true)],
            daysSinceVisit: 28, lat: 37.7983, lng: -122.4295))

        result.append(entry("mock_ankita", "Shizen", "370 14th St, San Francisco", .japanese,
            rating: 4, dishes: [("Agedashi Tofu", true)],
            daysSinceVisit: 35, lat: 37.7679, lng: -122.4194))

        // =================================================================
        // MARK: Pratha — Chinese / East Asian / dim sum
        // =================================================================

        result.append(entry("mock_pratha", "Laughing Buddha", "1413 Clement St, San Francisco", .chinese,
            rating: 5, dishes: [("Triple Mushroom Chow Mein", true), ("Kung Pao Tofu", true), ("Basil Curry Potatoes", true)],
            visitCount: 5, daysSinceVisit: 3, lat: 37.7828, lng: -122.4645))

        result.append(entry("mock_pratha", "Z & Y Restaurant", "655 Jackson St, San Francisco", .chinese,
            rating: 5, dishes: [("Mapo Tofu", true), ("Eggplant Garlic Sauce", true), ("Dry Sauteed String Beans", true)],
            visitCount: 4, daysSinceVisit: 6, lat: 37.7956, lng: -122.4065))

        result.append(entry("mock_pratha", "Terra Cotta Warrior", "2555 Judah St, San Francisco", .chinese,
            rating: 5, dishes: [("Shaanxi Cold Noodle", true), ("Veggie Stuffed Burger", true), ("Sesame Paste Noodle", true)],
            visitCount: 3, daysSinceVisit: 5, lat: 37.7608, lng: -122.4900))

        result.append(entry("mock_pratha", "Dragon Beaux", "5700 Geary Blvd, San Francisco", .chinese,
            rating: 5, dishes: [("Crystal Veggie Dumplings", true), ("Mushroom Bao", true), ("Taro Puffs", true)],
            visitCount: 4, daysSinceVisit: 8, lat: 37.7806, lng: -122.4728))

        result.append(entry("mock_pratha", "Sichuan Palace", "4201 Judah St, San Francisco", .chinese,
            rating: 5, dishes: [("Mapo Tofu", true), ("Scallion Pancake", true), ("Edamame", true)],
            visitCount: 3, daysSinceVisit: 10, lat: 37.7607, lng: -122.5014))

        result.append(entry("mock_pratha", "Kirin", "631 Kearny St, San Francisco", .chinese,
            rating: 4, dishes: [("Chinese Braised Tofu", true), ("Black Mushrooms & Baby Bok Choy", true), ("Buddha Vegetable", true)],
            visitCount: 2, daysSinceVisit: 14, lat: 37.7946, lng: -122.4052))

        result.append(entry("mock_pratha", "Burma Superstar", "309 Clement St, San Francisco", .other,
            rating: 4, dishes: [("Yellow Bean Tofu", true), ("Fiery Tofu", true), ("Eggplant Curry", true)],
            visitCount: 3, daysSinceVisit: 17, lat: 37.7828, lng: -122.4630))

        result.append(entry("mock_pratha", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 4, dishes: [("Masala Dosa", true)],
            daysSinceVisit: 22, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_pratha", "Hinodeya Ramen", "1560 Fillmore St, San Francisco", .japanese,
            rating: 4, dishes: [("Creamy Ramen", true), ("Edamame", true)],
            daysSinceVisit: 20, lat: 37.7835, lng: -122.4324))

        result.append(entry("mock_pratha", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 3, dishes: [("Margherita Pizza", false)],
            daysSinceVisit: 38, lat: 37.7589, lng: -122.4120))

        // =================================================================
        // MARK: Jay — Adventurous, tries everything
        // =================================================================

        result.append(entry("mock_jay", "Farmhouse Kitchen", "710 Florida St, San Francisco", .thai,
            rating: 5, dishes: [("Green Curry", true), ("Crispy Roti", true), ("Pad Thai Tofu", true)],
            visitCount: 3, daysSinceVisit: 3, lat: 37.7615, lng: -122.4115))

        result.append(entry("mock_jay", "Lao Table", "149 2nd St, San Francisco", .other,
            rating: 5, dishes: [("Nam Khao Crispy Rice Salad", true), ("Watermelon Peanut Salad", true), ("Bamboo Salad", true)],
            visitCount: 2, daysSinceVisit: 7, lat: 37.7864, lng: -122.3994))

        result.append(entry("mock_jay", "Shizen", "370 14th St, San Francisco", .japanese,
            rating: 5, dishes: [("Spicy Garlic Miso Ramen", true), ("Brussels Sprouts", true)],
            daysSinceVisit: 4, lat: 37.7679, lng: -122.4194))

        result.append(entry("mock_jay", "Rad Radish", "466 Haight St, San Francisco", .other,
            rating: 5, dishes: [("Avocado Toast", true), ("Chilaquiles", true), ("Chili Crisp Cauliflower", true)],
            visitCount: 4, daysSinceVisit: 5, lat: 37.7722, lng: -122.4310))

        result.append(entry("mock_jay", "Chicano Nuevo", "120 Sutter St, San Francisco", .mexican,
            rating: 5, dishes: [("Eggplant Parm", true), ("Cauliflower Balls", true), ("Semolina Garlic Bread", true)],
            visitCount: 2, daysSinceVisit: 10, lat: 37.7902, lng: -122.4014))

        result.append(entry("mock_jay", "Dragon Beaux", "5700 Geary Blvd, San Francisco", .chinese,
            rating: 5, dishes: [("Crystal Veggie Dumplings", true), ("Taro Puffs", true)],
            visitCount: 2, daysSinceVisit: 15, lat: 37.7806, lng: -122.4728))

        result.append(entry("mock_jay", "Souvla", "517 Hayes St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Greek Salad", true), ("Feta Dip", true)],
            daysSinceVisit: 20, lat: 37.7765, lng: -122.4261))

        result.append(entry("mock_jay", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Flatbread", true), ("Moroccan Couscous", true)],
            daysSinceVisit: 25, lat: 37.7749, lng: -122.4376))

        result.append(entry("mock_jay", "Tartine Manufactory", "595 Alabama St, San Francisco", .american,
            rating: 5, dishes: [("Morning Bun", true), ("Country Bread", true)],
            visitCount: 2, daysSinceVisit: 9, lat: 37.7644, lng: -122.4115))

        result.append(entry("mock_jay", "Dishoom", "1 Kearny St, San Francisco", .indian,
            rating: 4, dishes: [("Jackfruit Biryani", true), ("Gunpowder Potatoes", true)],
            daysSinceVisit: 18, lat: 37.7900, lng: -122.4033))

        result.append(entry("mock_jay", "Laughing Buddha", "1413 Clement St, San Francisco", .chinese,
            rating: 4, dishes: [("Szechwan Chili Tofu Soup", true), ("Many Treasures", true)],
            daysSinceVisit: 28, lat: 37.7828, lng: -122.4645))

        result.append(entry("mock_jay", "Chouchou", "400 Dewey Blvd, San Francisco", .french,
            rating: 4, dishes: [("Baked Brie", true), ("Chocolate Mousse", true)],
            daysSinceVisit: 35, lat: 37.7444, lng: -122.4642))

        return result
    }

    /// Build mock CircleMember objects so friend-name lookups work in NewHomeView.
    static func buildMembers() -> [FirestoreService.CircleMember] {
        guard mockEnabled else { return [] }
        return friends.map { FirestoreService.CircleMember(uid: $0.uid, displayName: $0.displayName) }
    }
}
