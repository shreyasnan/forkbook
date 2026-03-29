import Foundation

// MARK: - Auto-detect cuisine from restaurant name/subtitle

struct CuisineDetector {

    /// Attempts to guess the cuisine type from a restaurant name and optional address/subtitle.
    /// Returns nil if no confident match is found.
    static func detect(name: String, subtitle: String = "") -> CuisineType? {
        let text = "\(name) \(subtitle)".lowercased()

        // Check each cuisine's keywords — order matters (more specific first)
        for (cuisine, keywords) in cuisineKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    return cuisine
                }
            }
        }

        return nil
    }

    // MARK: - Keyword mappings

    private static let cuisineKeywords: [(CuisineType, [String])] = [
        (.japanese, [
            "sushi", "ramen", "izakaya", "yakitori", "tempura", "udon", "soba",
            "teriyaki", "omakase", "hibachi", "teppanyaki", "tonkatsu", "matcha",
            "sake", "japanese", "nippon", "miso", "donburi", "gyoza", "bento"
        ]),
        (.korean, [
            "korean", "bibimbap", "kimchi", "bulgogi", "galbi", "kbbq",
            "banchan", "tteok", "soju", "gogi", "chimaek", "sundubu",
            "jjigae", "samgyeopsal", "pojangmacha"
        ]),
        (.chinese, [
            "chinese", "dim sum", "dumpling", "wok", "szechuan", "sichuan",
            "cantonese", "hunan", "peking", "kung pao", "lo mein", "chow mein",
            "bao", "noodle house", "panda", "dragon", "golden", "jade",
            "hong kong", "shanghainese", "mapo"
        ]),
        (.vietnamese, [
            "vietnamese", "pho", "banh mi", "bun bo", "vermicelli",
            "spring roll", "saigon", "hanoi", "viet"
        ]),
        (.thai, [
            "thai", "pad thai", "tom yum", "green curry", "basil",
            "bangkok", "satay", "larb", "som tum", "sticky rice"
        ]),
        (.indian, [
            "indian", "curry house", "tandoori", "tikka", "masala",
            "naan", "biryani", "dosa", "chaat", "dal", "paneer",
            "mughlai", "dhaba", "bombay", "mumbai", "delhi",
            "punjabi", "south indian", "kerala"
        ]),
        (.italian, [
            "italian", "pizza", "pizzeria", "trattoria", "ristorante",
            "osteria", "pasta", "gelato", "espresso", "cappuccino",
            "il ", "la ", "napoli", "romano", "tuscan", "sicilian",
            "calzone", "bruschetta", "antipasto"
        ]),
        (.french, [
            "french", "bistro", "brasserie", "patisserie", "boulangerie",
            "creperie", "cafe de", "chez ", "le ", "croissant",
            "escargot", "provencal", "lyon"
        ]),
        (.mexican, [
            "mexican", "taqueria", "taco", "burrito", "enchilada",
            "cantina", "mezcal", "margarita", "salsa", "guacamole",
            "tortilla", "quesadilla", "tamale", "pozole", "mole",
            "oaxaca", "jalisco", "azteca"
        ]),
        (.mediterranean, [
            "mediterranean", "greek", "kebab", "falafel", "hummus",
            "shawarma", "gyro", "pita", "tahini", "mezze",
            "turkish", "lebanese", "persian", "moroccan", "halal",
            "hookah", "olive"
        ]),
        (.american, [
            "burger", "bbq", "barbecue", "grill", "steakhouse", "steak house",
            "diner", "wings", "fried chicken", "smokehouse", "brew pub",
            "brewpub", "sports bar", "american", "soul food", "cajun",
            "southern", "tex-mex"
        ]),
    ]
}
