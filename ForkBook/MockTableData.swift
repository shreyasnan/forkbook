import Foundation

// MARK: - Mock Table Data
//
// Seeds the "My Table" with 5 friends and ~6 restaurants each so the hero card
// has real signal diversity to prioritize across. Used only when the real
// circle comes back empty (first-run / no circle / solo mode).
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
        MockFriend(uid: "mock_pragya",  displayName: "Pragya"),         // Sushi/Japanese enthusiast
        MockFriend(uid: "mock_puneet",  displayName: "Puneet"),         // Indian food devotee
        MockFriend(uid: "mock_ankita",  displayName: "Ankita"),         // Italian / date-night
        MockFriend(uid: "mock_pratha",  displayName: "Pratha"),         // Chinese / dim sum
        MockFriend(uid: "mock_jay",     displayName: "Jay"),            // Adventurous, tries everything
    ]

    // MARK: - Public API

    /// Build mock SharedRestaurant entries with relative dates anchored to now.
    static func buildSharedRestaurants() -> [SharedRestaurant] {
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

        // MARK: Pragya — Sushi / Japanese enthusiast

        result.append(entry("mock_pragya", "Ju-Ni", "1335 Fulton St, San Francisco", .japanese,
            rating: 5, dishes: [("Omakase", true), ("Uni Toast", true), ("A5 Wagyu", true)],
            visitCount: 2, daysSinceVisit: 3, lat: 37.7769, lng: -122.4367))

        result.append(entry("mock_pragya", "Robin", "620 Gough St, San Francisco", .japanese,
            rating: 5, dishes: [("Omakase", true), ("Hamachi Crudo", true)],
            daysSinceVisit: 12, lat: 37.7789, lng: -122.4229))

        result.append(entry("mock_pragya", "Marufuku Ramen", "1581 Webster St, San Francisco", .japanese,
            rating: 4, dishes: [("Tonkotsu Ramen", true), ("Gyoza", true)],
            visitCount: 3, daysSinceVisit: 8, lat: 37.7850, lng: -122.4310))

        result.append(entry("mock_pragya", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 4, dishes: [("Masala Dosa", true)],
            daysSinceVisit: 21, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_pragya", "Tartine Manufactory", "595 Alabama St, San Francisco", .american,
            rating: 5, dishes: [("Morning Bun", true), ("Country Bread", true)],
            visitCount: 2, daysSinceVisit: 5, lat: 37.7644, lng: -122.4115))

        result.append(entry("mock_pragya", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 3, dishes: [("Moroccan Couscous", false)],
            daysSinceVisit: 40, lat: 37.7749, lng: -122.4376))

        // MARK: Puneet — Indian food devotee

        result.append(entry("mock_puneet", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 5, dishes: [("Masala Dosa", true), ("Filter Coffee", true), ("Idli Sambar", true)],
            visitCount: 4, daysSinceVisit: 2, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_puneet", "Ju-Ni", "1335 Fulton St, San Francisco", .japanese,
            rating: 5, dishes: [("Omakase", true)],
            daysSinceVisit: 18, lat: 37.7769, lng: -122.4367))

        result.append(entry("mock_puneet", "Besharam", "1275 Minnesota St, San Francisco", .indian,
            rating: 5, dishes: [("Lamb Biryani", true), ("Butter Chicken", true)],
            visitCount: 3, daysSinceVisit: 6, lat: 37.7605, lng: -122.3889))

        result.append(entry("mock_puneet", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 4, dishes: [("Pappardelle", true)],
            daysSinceVisit: 14, lat: 37.7589, lng: -122.4120))

        result.append(entry("mock_puneet", "Han Il Kwan", "1802 Balboa St, San Francisco", .korean,
            rating: 4, dishes: [("Bibimbap", true), ("Bulgogi", true)],
            daysSinceVisit: 25, lat: 37.7757, lng: -122.4773))

        result.append(entry("mock_puneet", "La Taqueria", "2889 Mission St, San Francisco", .mexican,
            rating: 4, dishes: [("Carnitas Burrito", true)],
            visitCount: 2, daysSinceVisit: 9, lat: 37.7508, lng: -122.4186))

        // MARK: Ankita — Italian / Mediterranean / date-night

        result.append(entry("mock_ankita", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 5, dishes: [("Pappardelle", true), ("Margherita Pizza", true), ("Burrata", true)],
            visitCount: 3, daysSinceVisit: 4, lat: 37.7589, lng: -122.4120))

        result.append(entry("mock_ankita", "Delfina", "3621 18th St, San Francisco", .italian,
            rating: 5, dishes: [("Spaghetti", true), ("Tiramisu", true)],
            visitCount: 2, daysSinceVisit: 11, lat: 37.7615, lng: -122.4244))

        result.append(entry("mock_ankita", "Souvla", "517 Hayes St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Lamb Gyro", true), ("Greek Salad", true)],
            visitCount: 4, daysSinceVisit: 7, lat: 37.7765, lng: -122.4261))

        result.append(entry("mock_ankita", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Moroccan Couscous", true), ("Flatbread", true)],
            visitCount: 2, daysSinceVisit: 15, lat: 37.7749, lng: -122.4376))

        result.append(entry("mock_ankita", "Ju-Ni", "1335 Fulton St, San Francisco", .japanese,
            rating: 4, dishes: [("Omakase", true)],
            daysSinceVisit: 30, lat: 37.7769, lng: -122.4367))

        result.append(entry("mock_ankita", "La Taqueria", "2889 Mission St, San Francisco", .mexican,
            rating: 3, dishes: [],
            daysSinceVisit: 55, lat: 37.7508, lng: -122.4186))

        // MARK: Pratha — Chinese / dim sum / casual

        result.append(entry("mock_pratha", "Dragon Beaux", "5700 Geary Blvd, San Francisco", .chinese,
            rating: 5, dishes: [("Shrimp Har Gow", true), ("Xiaolongbao", true), ("Char Siu Bao", true)],
            visitCount: 5, daysSinceVisit: 6, lat: 37.7806, lng: -122.4728))

        result.append(entry("mock_pratha", "Z & Y Restaurant", "655 Jackson St, San Francisco", .chinese,
            rating: 5, dishes: [("Mapo Tofu", true), ("Dan Dan Noodles", true)],
            visitCount: 3, daysSinceVisit: 10, lat: 37.7956, lng: -122.4065))

        result.append(entry("mock_pratha", "Marufuku Ramen", "1581 Webster St, San Francisco", .japanese,
            rating: 4, dishes: [("Tonkotsu Ramen", true)],
            visitCount: 2, daysSinceVisit: 16, lat: 37.7850, lng: -122.4310))

        result.append(entry("mock_pratha", "Super Duper Burgers", "721 Market St, San Francisco", .american,
            rating: 4, dishes: [("Mini Burger", true), ("Garlic Fries", true)],
            visitCount: 6, daysSinceVisit: 3, lat: 37.7870, lng: -122.4027))

        result.append(entry("mock_pratha", "Dosa Point", "2447 3rd St, San Francisco", .indian,
            rating: 4, dishes: [("Masala Dosa", true)],
            daysSinceVisit: 22, lat: 37.7578, lng: -122.3886))

        result.append(entry("mock_pratha", "Flour + Water", "2401 Harrison St, San Francisco", .italian,
            rating: 3, dishes: [("Pappardelle", false)],
            daysSinceVisit: 35, lat: 37.7589, lng: -122.4120))

        // MARK: Jay — Adventurous, mixed portfolio

        result.append(entry("mock_jay", "Kin Khao", "55 Cyril Magnin St, San Francisco", .thai,
            rating: 5, dishes: [("Rabbit Curry", true), ("Khao Soi", true)],
            visitCount: 2, daysSinceVisit: 9, lat: 37.7855, lng: -122.4095))

        result.append(entry("mock_jay", "Turtle Tower", "501 3rd St, San Francisco", .vietnamese,
            rating: 5, dishes: [("Pho Ga", true), ("Banh Mi", true)],
            visitCount: 3, daysSinceVisit: 5, lat: 37.7811, lng: -122.3946))

        result.append(entry("mock_jay", "Ju-Ni", "1335 Fulton St, San Francisco", .japanese,
            rating: 5, dishes: [("Omakase", true), ("Uni Toast", true)],
            daysSinceVisit: 2, lat: 37.7769, lng: -122.4367))

        result.append(entry("mock_jay", "Besharam", "1275 Minnesota St, San Francisco", .indian,
            rating: 4, dishes: [("Lamb Biryani", true)],
            daysSinceVisit: 13, lat: 37.7605, lng: -122.3889))

        result.append(entry("mock_jay", "Dragon Beaux", "5700 Geary Blvd, San Francisco", .chinese,
            rating: 5, dishes: [("Xiaolongbao", true), ("Shrimp Har Gow", true)],
            visitCount: 2, daysSinceVisit: 19, lat: 37.7806, lng: -122.4728))

        result.append(entry("mock_jay", "Souvla", "517 Hayes St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Lamb Gyro", true)],
            daysSinceVisit: 28, lat: 37.7765, lng: -122.4261))

        result.append(entry("mock_jay", "Nopa", "560 Divisadero St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Flatbread", true)],
            daysSinceVisit: 45, lat: 37.7749, lng: -122.4376))

        // =====================================================================
        // MARK: Additional restaurants sourced from bay_area_menus DB
        // =====================================================================

        // MARK: Pragya (cont.) — More Japanese depth

        result.append(entry("mock_pragya", "Nara", "518 Haight St, San Francisco", .japanese,
            rating: 5, dishes: [("O-Toro", true), ("Hamachi", true), ("Ikura", true)],
            visitCount: 3, daysSinceVisit: 7, lat: 37.7716, lng: -122.4313))

        result.append(entry("mock_pragya", "Ebisu", "1283 9th Ave, San Francisco", .japanese,
            rating: 4, dishes: [("Hamachi Sashimi", true), ("Aji Tataki", true)],
            visitCount: 2, daysSinceVisit: 14, lat: 37.7634, lng: -122.4660))

        result.append(entry("mock_pragya", "Shizen", "370 14th St, San Francisco", .japanese,
            rating: 5, dishes: [("Spicy Garlic Miso Ramen", true), ("Shiitake Maki", true)],
            daysSinceVisit: 20, lat: 37.7679, lng: -122.4194))

        // MARK: Puneet (cont.) — Indian breadth

        result.append(entry("mock_puneet", "Dishoom", "1 Kearny St, San Francisco", .indian,
            rating: 5, dishes: [("Chicken Ruby", true), ("Charred Lamb Chops", true), ("Bhel", true)],
            visitCount: 2, daysSinceVisit: 4, lat: 37.7900, lng: -122.4033))

        result.append(entry("mock_puneet", "Masala Dosa", "981 Valencia St, San Francisco", .indian,
            rating: 4, dishes: [("Samosa", true), ("Aloo Gobi", true), ("Bhindi Masala", true)],
            visitCount: 3, daysSinceVisit: 11, lat: 37.7575, lng: -122.4212))

        result.append(entry("mock_puneet", "Chaat Corner", "55 E 3rd Ave, San Mateo", .indian,
            rating: 4, dishes: [("Pav Bhaji", true), ("Chole Bhature", true)],
            daysSinceVisit: 19, lat: 37.5633, lng: -122.3232))

        // MARK: Ankita (cont.) — Date-night / French / Mediterranean

        result.append(entry("mock_ankita", "Chouchou", "400 Dewey Blvd, San Francisco", .french,
            rating: 5, dishes: [("Boeuf Bourguignon", true), ("Cassoulet", true), ("Baked Brie", true)],
            visitCount: 2, daysSinceVisit: 8, lat: 37.7444, lng: -122.4642))

        result.append(entry("mock_ankita", "Frascati", "1901 Hyde St, San Francisco", .mediterranean,
            rating: 5, dishes: [("Fresh Fettuccini", true), ("Burrata", true), ("Panna Cotta", true)],
            visitCount: 3, daysSinceVisit: 13, lat: 37.7939, lng: -122.4185))

        result.append(entry("mock_ankita", "Starbelly", "3583 16th St, San Francisco", .mediterranean,
            rating: 4, dishes: [("Baked Eggs", true), ("Biscuits and Gravy", true)],
            daysSinceVisit: 22, lat: 37.7641, lng: -122.4318))

        // MARK: Pratha (cont.) — More Chinese variety

        result.append(entry("mock_pratha", "Terra Cotta Warrior", "2555 Judah St, San Francisco", .chinese,
            rating: 5, dishes: [("Biang-Biang Noodles", true), ("Lamb Burger", true)],
            visitCount: 4, daysSinceVisit: 5, lat: 37.7608, lng: -122.4900))

        result.append(entry("mock_pratha", "Laughing Buddha", "1413 Clement St, San Francisco", .chinese,
            rating: 4, dishes: [("Triple Mushroom Chow Mein", true), ("Kung Pao Tofu", true)],
            visitCount: 2, daysSinceVisit: 12, lat: 37.7828, lng: -122.4645))

        result.append(entry("mock_pratha", "House of Thai", "901 Larkin St, San Francisco", .thai,
            rating: 4, dishes: [("Pad Thai", true), ("Mango Sticky Rice", true)],
            daysSinceVisit: 17, lat: 37.7870, lng: -122.4173))

        // MARK: Jay (cont.) — More adventurous range

        result.append(entry("mock_jay", "Farmhouse Kitchen", "710 Florida St, San Francisco", .thai,
            rating: 5, dishes: [("24 Hours Beef Noodle Soup", true), ("Basil Bomb", true)],
            visitCount: 3, daysSinceVisit: 6, lat: 37.7615, lng: -122.4115))

        result.append(entry("mock_jay", "Lao Table", "149 2nd St, San Francisco", .other,
            rating: 5, dishes: [("Crying Tiger Steak", true), ("Nam Khao Crispy Rice", true), ("Larb Duck", true)],
            visitCount: 2, daysSinceVisit: 10, lat: 37.7864, lng: -122.3994))

        result.append(entry("mock_jay", "lily", "419 O'Farrell St, San Francisco", .vietnamese,
            rating: 5, dishes: [("Garlic Noodle", true), ("Shaking Beef Salad", true), ("Bun Cha Hanoi", true)],
            daysSinceVisit: 15, lat: 37.7860, lng: -122.4111))

        result.append(entry("mock_jay", "Mission Street Oyster Bar", "2162 Mission St, San Francisco", .other,
            rating: 4, dishes: [("Clam Chowder", true), ("Alaskan Cod", true)],
            daysSinceVisit: 30, lat: 37.7628, lng: -122.4195))

        return result
    }

    /// Build mock CircleMember objects so friend-name lookups work in NewHomeView.
    static func buildMembers() -> [FirestoreService.CircleMember] {
        friends.map { FirestoreService.CircleMember(uid: $0.uid, displayName: $0.displayName) }
    }
}
