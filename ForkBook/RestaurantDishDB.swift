import Foundation

// MARK: - Restaurant Dish Database
// Hand-curated popular dishes for Bay Area restaurants
// Generated: 2026-04-01
// Re-generate: python3 Scripts/yelp_scraper.py --export

struct RestaurantDishDB {
    /// Lookup dishes by restaurant name (lowercase key)
    static let dishes: [String: [String]] = [

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // SAN FRANCISCO
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Japanese / Sushi / Ramen ─────────────────────────────────────
        "marufuku ramen": ["Hakata Tonkotsu Ramen", "Spicy Chicken Ramen", "Chashu Don", "Gyoza", "Karaage"],
        "mensho tokyo": ["Tori Paitan Ramen", "Vegan Tantanmen", "Chashu Pork Bun", "Duck Tsukemen"],
        "nojo ramen tavern": ["Chicken Paitan Ramen", "Spicy Miso Ramen", "Pork Belly Bun"],
        "hinodeya ramen": ["Shio Ramen", "Miso Ramen", "Shoyu Ramen", "Yuzu Shio Ramen"],
        "sushi ran": ["Omakase", "Hamachi Sashimi", "Uni Nigiri", "Spider Roll", "Wagyu Tataki"],
        "kusakabe": ["Omakase", "Sashimi Course", "Wagyu", "Uni", "Toro"],
        "robin": ["Omakase", "Uni Toast", "A5 Wagyu", "Hamachi Crudo"],
        "ju-ni": ["Omakase", "Otoro", "Uni", "Ikura", "Nodoguro"],
        "nomica": ["Chirashi Bowl", "Miso Cod", "Karaage", "Wagyu Tataki", "Hamachi Crudo"],
        "udon mugizo": ["Nabeyaki Udon", "Curry Udon", "Tempura Udon", "Kitsune Udon"],
        "izakaya rintaro": ["Grilled Rice Ball", "Tempura", "Sashimi", "Chicken Karaage", "Pork Gyoza"],
        "nari": ["Khao Soi", "Crying Tiger", "Papaya Salad", "Crab Fried Rice", "Coconut Sticky Rice"],
        "saru sushi bar": ["Chirashi Don", "Omakase", "Dragon Roll", "Yellowtail Jalapeño"],
        "domo sushi": ["Sashimi Combo", "Spider Roll", "Rainbow Roll", "Salmon Belly"],
        "waraku": ["Omurice", "Curry Udon", "Ramen", "Gyoza", "Takoyaki"],
        "sushi zone": ["Omakase", "Uni", "Toro Sashimi", "Chef's Special Roll"],
        "ryoko's": ["Sashimi Plate", "Hand Roll", "Yakitori", "Edamame", "Sake"],

        // ── Chinese / Dim Sum ────────────────────────────────────────────
        "z & y restaurant": ["Sichuan Boiled Fish", "Mapo Tofu", "Dan Dan Noodles", "Kung Pao Chicken", "Chili Wontons"],
        "china live": ["Peking Duck", "Xiao Long Bao", "Mapo Tofu", "Salt & Pepper Crab", "Dan Dan Noodles"],
        "mister jiu's": ["Cheong Fun", "Smoked Duck", "Hot & Sour Soup", "Char Siu Pork", "Turnip Cake"],
        "lai hong lounge": ["Har Gow", "Siu Mai", "Char Siu Bao", "Cheung Fun", "Egg Tart"],
        "hong kong lounge": ["Har Gow", "Siu Mai", "XO Rice Noodle Roll", "BBQ Pork Bun", "Turnip Cake"],
        "yank sing": ["Shanghai Soup Dumplings", "Har Gow", "Peking Duck", "Siu Mai", "Egg Custard Tart"],
        "dragon beaux": ["Xiao Long Bao", "Har Gow", "Siu Mai", "Truffle Dumplings", "BBQ Pork Bun"],
        "dumpling home": ["Xiao Long Bao", "Pan Fried Dumplings", "Wontons in Chili Oil", "Scallion Pancake"],
        "san tung": ["Dry Fried Chicken Wings", "Dan Dan Noodles", "Wontons", "Potstickers"],
        "kingdom of dumpling": ["Xiao Long Bao", "Pork Dumplings", "Wontons in Chili Oil", "Scallion Pancake"],
        "chili house": ["Cumin Lamb", "Kung Pao Chicken", "Mapo Tofu", "Sichuan Wontons", "Hot Pot"],
        "r&g lounge": ["Salt & Pepper Crab", "Peking Duck", "Walnut Prawns", "Clay Pot Rice"],
        "good mong kok bakery": ["Egg Tart", "BBQ Pork Bun", "Pineapple Bun", "Coconut Bun", "Dan Tat"],
        "house of pancakes": ["Scallion Pancake", "Beef Roll", "Pan Fried Dumplings", "Wonton Soup"],
        "old mandarin islamic": ["Lamb Noodle Soup", "Cumin Lamb", "Beef Pancake", "Cold Noodles"],

        // ── Korean ───────────────────────────────────────────────────────
        "um.ma": ["Galbi Jjim", "Kimchi Jjigae", "Japchae", "Bulgogi", "Doenjang Jjigae"],
        "han il kwan": ["Galbi", "Bulgogi", "Bibimbap", "Kimchi Jjigae", "Haemul Pajeon"],
        "toyose": ["BBQ Short Ribs", "Spicy Pork", "Kimchi Fried Rice", "Japchae", "Army Stew"],
        "namu gaji": ["Okonomiyaki", "Korean Fried Chicken", "Bibimbap", "Japchae"],
        "daeho kalbijjim & beef soup": ["Galbi Jjim", "Beef Bone Soup", "Bulgogi", "Kimchi Stew"],
        "jang su jang": ["Galbi", "Sundubu Jjigae", "Bulgogi", "Kimchi Pancake", "Bibim Naengmyeon"],
        "my tofu house": ["Sundubu Jjigae", "Bibimbap", "Kimchi Jjigae", "Galbi"],

        // ── Indian ───────────────────────────────────────────────────────
        "dosa": ["Masala Dosa", "Uttapam", "Rava Dosa", "Idli Sambar", "Vada"],
        "copra": ["Butter Chicken", "Lamb Rogan Josh", "Garlic Naan", "Samosa", "Mango Lassi"],
        "rooh": ["Butter Chicken", "Lamb Seekh Kebab", "Paneer Tikka", "Biryani", "Gulab Jamun"],
        "august 1 five": ["Chicken Tikka Masala", "Lamb Biryani", "Garlic Naan", "Samosa Chaat"],
        "curry up now": ["Tikka Masala Burrito", "Samosa Sliders", "Deconstructed Samosa", "Naan Pizza"],
        "amber india": ["Tandoori Platter", "Butter Chicken", "Lamb Vindaloo", "Garlic Naan", "Mango Kulfi"],
        "kasa indian eatery": ["Chicken Tikka Wrap", "Lamb Kebab Roll", "Chana Masala", "Samosa"],

        // ── Mexican / Latin ──────────────────────────────────────────────
        "la taqueria": ["Super Burrito", "Carne Asada Taco", "Carnitas Taco", "Al Pastor Taco", "Horchata"],
        "el farolito": ["Super Burrito", "Quesadilla Suiza", "Carne Asada Taco", "Al Pastor Taco"],
        "taqueria cancun": ["Super Burrito", "Carnitas Taco", "Carne Asada Taco", "Quesadilla"],
        "papalote mexican grill": ["Triple Threat Burrito", "Carne Asada Burrito", "Chicken Mole Burrito"],
        "nopalito": ["Carnitas", "Pozole", "Enchiladas Suizas", "Tamales", "Churros"],
        "cala": ["Mole Negro", "Aguachile", "Carnitas", "Elote", "Churros"],
        "loló": ["Fried Plantains", "Al Pastor Taco", "Mole Enchiladas", "Elote"],
        "gracias madre": ["Cauliflower Tacos", "Cashew Queso", "Plantain Enchiladas", "Churros"],
        "taqueria el buen sabor": ["Al Pastor Burrito", "Carnitas Taco", "Horchata", "Nachos"],
        "el techo": ["Ceviche", "Empanadas", "Grilled Corn", "Fish Tacos", "Churros"],
        "tropisueño": ["Guacamole", "Carnitas", "Fish Tacos", "Churros", "Margarita"],

        // ── Italian ──────────────────────────────────────────────────────
        "flour + water": ["Pasta Tasting Menu", "Margherita Pizza", "Agnolotti", "Tagliatelle Bolognese"],
        "a16": ["Margherita Pizza", "Burrata", "Panna Cotta", "Meatballs", "Rigatoni"],
        "delfina": ["Spaghetti", "Buttermilk Panna Cotta", "Roasted Chicken", "Pappardelle"],
        "cotogna": ["Tagliatelle", "Wood-Fired Pizza", "Risotto", "Panna Cotta"],
        "tony's pizza napoletana": ["Margherita Pizza", "Cal Italia Pizza", "Burrata", "Tiramisu"],
        "piccino": ["Margherita Pizza", "Burrata", "Panna Cotta", "Risotto"],
        "delarosa": ["Margherita Pizza", "Burrata", "Carbonara", "Meatballs"],
        "sistema": ["Cacio e Pepe", "Pappardelle", "Burrata", "Tiramisu"],
        "che fico": ["Wood-Fired Pizza", "Cacio e Pepe", "Focaccia", "Burrata", "Lamb Sugo"],
        "ideale": ["Ravioli", "Osso Buco", "Tiramisu", "Panna Cotta", "Risotto"],
        "beretta": ["Margherita Pizza", "Burrata", "Meatballs", "Affogato", "Arancini"],
        "il casaro pizzeria": ["Margherita Pizza", "Diavola Pizza", "Caprese", "Tiramisu"],
        "montesacro": ["Pinsa Romana", "Cacio e Pepe", "Burrata", "Supplì"],

        // ── American / New American / Brunch ─────────────────────────────
        "zuni cafe": ["Zuni Roast Chicken", "Caesar Salad", "Burger", "Espresso Granita"],
        "tartine manufactory": ["Morning Bun", "Croque Monsieur", "Tartine Bread", "Croissant"],
        "tartine bakery": ["Morning Bun", "Croissant", "Country Bread", "Banana Cream Tart"],
        "foreign cinema": ["Steak Frites", "Oysters", "Duck Confit", "Crème Brûlée"],
        "nopa": ["Burger", "Wood-Fired Rotisserie Chicken", "Flatbread", "Pork Chop"],
        "state bird provisions": ["State Bird (Quail)", "Pancake with Uni", "Garlic Bread", "Duck Liver Mousse"],
        "rich table": ["Sardine Chips", "Porcini Doughnuts", "Dried Fruit Pasta", "Duck"],
        "lazy bear": ["Tasting Menu", "Granola", "Bone Marrow", "Smoked Trout"],
        "house of prime rib": ["King Cut Prime Rib", "Queen Cut Prime Rib", "English Cut", "Creamed Spinach"],
        "mama's on washington square": ["Monte Cristo", "French Toast", "Eggs Benedict", "Pancakes"],
        "plow": ["Lemon Ricotta Pancakes", "Plow Hash", "Fried Egg Sandwich", "Granola"],
        "zazie": ["Eggs Benedict", "French Toast", "Croque Madame", "Shakshuka"],
        "kitchen story": ["Millionaire's Bacon", "Ube Pancakes", "Eggs Benedict", "Avocado Toast"],
        "the progress": ["Tasting Menu", "Seasonal Dishes", "Wagyu", "Vegetable Course"],
        "spruce": ["Burger", "Steak", "Seasonal Tasting", "Butterscotch Pudding"],
        "marlowe": ["Burger", "Brussels Sprouts", "Duck Fat Fries", "Butterscotch Pudding"],
        "the snug": ["Burger", "Fish & Chips", "Wings", "Cobb Salad"],
        "the grove": ["Avocado Toast", "Breakfast Burrito", "Açaí Bowl", "Turkey Sandwich"],
        "sweet maple": ["Millionaire's Bacon", "Eggs Benedict", "Buttermilk Pancakes", "Fried Chicken & Waffles"],
        "brenda's french soul food": ["Beignets", "Crawfish Beignets", "Shrimp & Grits", "Po' Boy", "Jambalaya"],
        "wayfare tavern": ["Fried Chicken", "Burger", "Deviled Eggs", "Mac & Cheese"],
        "the cavalier": ["Scotch Egg", "Fish & Chips", "Burger", "Sticky Toffee Pudding"],

        // ── Seafood ──────────────────────────────────────────────────────
        "anchor oyster bar": ["Cioppino", "Oysters", "Clam Chowder", "Crab Louie", "Fried Calamari"],
        "swan oyster depot": ["Oysters", "Crab Back", "Smoked Trout", "Lobster Salad", "Clam Chowder"],
        "hog island oyster co.": ["Oysters", "Clam Chowder", "Grilled Cheese", "Manila Clams"],
        "sotto mare": ["Cioppino", "Crab Sandwich", "Clam Chowder", "Fried Calamari"],
        "woodhouse fish co.": ["Lobster Roll", "Fish & Chips", "Clam Chowder", "Fish Tacos"],
        "waterbar": ["Oysters", "Lobster Tail", "Seared Scallops", "Crab Tower", "Cioppino"],
        "scoma's": ["Cioppino", "Crab Louie", "Fisherman's Stew", "Petrale Sole"],
        "wipeout bar & grill": ["Fish Tacos", "Shrimp Po' Boy", "Clam Chowder", "Calamari"],

        // ── Thai ─────────────────────────────────────────────────────────
        "kin khao": ["Khao Soi", "Green Curry", "Crab Fried Rice", "Papaya Salad", "Crying Tiger"],
        "farmhouse kitchen": ["Pad Thai", "Khao Soi", "Boat Noodles", "Mango Sticky Rice", "Crying Tiger"],
        "thai house express": ["Pad Thai", "Tom Kha Gai", "Green Curry", "Pad See Ew", "Thai Iced Tea"],
        "osha thai": ["Pad Thai", "Drunken Noodles", "Tom Yum", "Papaya Salad"],
        "basil thai": ["Pad Thai", "Green Curry", "Panang Curry", "Thai Iced Tea", "Spring Rolls"],
        "marnee thai": ["Pad Thai", "Massaman Curry", "Larb", "Tom Kha Gai"],
        "lers ros": ["Pad Kra Pao", "Crispy Pork Belly", "Tom Yum", "Papaya Salad", "Pad Thai"],

        // ── Vietnamese ───────────────────────────────────────────────────
        "the slanted door": ["Shaking Beef", "Spring Rolls", "Cellophane Noodles", "Chicken Claypot"],
        "turtle tower": ["Pho Ga", "Pho Bo", "Bun Cha", "Banh Cuon"],
        "pho 2000": ["Pho Tai", "Bun Bo Hue", "Banh Mi", "Spring Rolls"],
        "yummy yummy": ["Pho Dac Biet", "Salt & Pepper Chicken Wings", "Bun Bo Hue", "Banh Mi"],
        "saigon sandwich": ["Banh Mi", "Vietnamese Coffee", "Spring Rolls"],

        // ── French ───────────────────────────────────────────────────────
        "café claude": ["Steak Frites", "Croque Monsieur", "Moules Frites", "Crème Brûlée"],
        "chapeau!": ["Duck Confit", "Bouillabaisse", "Coq au Vin", "Crème Brûlée"],
        "café jacqueline": ["Gruyère Soufflé", "Chocolate Soufflé", "Mushroom Soufflé"],
        "chez maman": ["Croque Monsieur", "French Onion Soup", "Steak Frites", "Crêpes"],

        // ── Mediterranean ────────────────────────────────────────────────
        "kokkari estiatorio": ["Lamb Chops", "Grilled Octopus", "Moussaka", "Loukoumades"],
        "souvla": ["Lamb Wrap", "Chicken Wrap", "Greek Salad", "Frozen Yogurt", "Baklava"],
        "oren's hummus": ["Hummus", "Falafel", "Shawarma", "Pita", "Schnitzel"],
        "barzotto": ["Hand-Cut Pasta", "Spaghetti Pomodoro", "Bucatini", "Gelato"],

        // ── Bakeries / Dessert / Coffee ──────────────────────────────────
        "b. patisserie": ["Kouign Amann", "Croissant", "Tart", "Macaron", "Bostock"],
        "golden boy pizza": ["Pepperoni Pizza", "Clam & Garlic Pizza", "Combination Pizza"],
        "arsicault bakery": ["Croissant", "Pain au Chocolat", "Ham & Cheese Croissant", "Almond Croissant"],
        "mr. holmes bakehouse": ["Cruffin", "Croissant", "Donut"],
        "devil's teeth baking company": ["Breakfast Sandwich", "Beignets", "Cinnamon Roll"],
        "garden creamery": ["Ube Ice Cream", "Mango Ice Cream", "Matcha Ice Cream"],
        "craftsman and wolves": ["The Rebel Within", "Morning Bun", "Chocolate Cake", "Danish"],
        "arizmendi bakery": ["Sourdough Pizza", "Scone", "Focaccia", "Croissant"],
        "noe valley bakery": ["Scone", "Croissant", "Cupcake", "Sourdough Bread"],
        "bi-rite creamery": ["Salted Caramel Ice Cream", "Balsamic Strawberry", "Brown Sugar with Ginger"],
        "smitten ice cream": ["Vanilla Bean", "Strawberry", "Cookies & Cream", "Seasonal Flavor"],
        "dandelion chocolate": ["Hot Chocolate", "Chocolate Truffle", "S'more", "Brownie"],

        // ── Burgers ──────────────────────────────────────────────────────
        "super duper burgers": ["Super Burger", "Garlic Fries", "Mini Burger", "Milkshake"],
        "in-n-out burger": ["Double-Double", "Animal Style Fries", "Protein Style Burger", "Milkshake"],
        "roam artisan burgers": ["Classic Burger", "Bison Burger", "Elk Burger", "Sweet Potato Fries"],
        "gott's roadside": ["Cheeseburger", "Ahi Tuna Burger", "Garlic Fries", "Milkshake"],

        // ── Popular Chains / Casual ──────────────────────────────────────
        "cheesecake factory": ["Avocado Egg Rolls", "Louisiana Chicken Pasta", "Cheesecake", "Bang Bang Chicken"],
        "philz coffee": ["Mint Mojito Iced Coffee", "Tesora", "Ether", "Silken Splendor"],
        "tartine": ["Morning Bun", "Croissant", "Country Bread", "Croque Monsieur"],
        "peet's coffee": ["Caffe Latte", "Mocha", "Chai Latte", "Cold Brew"],
        "blue bottle coffee": ["New Orleans Iced Coffee", "Drip Coffee", "Latte", "Liège Waffle"],
        "ike's love & sandwiches": ["Matt Cain", "Menage a Trois", "Kryptonite", "Malibu"],
        "señor sisig": ["Sisig Burrito", "Sisig Fries", "Sisig Nachos", "Lumpia"],
        "urban plates": ["Grilled Salmon", "Steak Plate", "Roasted Chicken", "Mac & Cheese"],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // EAST BAY (Oakland / Berkeley / Emeryville)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "chez panisse": ["Prix Fixe Dinner", "Calzone", "Seasonal Salad", "Wood-Fired Pizza"],
        "ippuku": ["Yakitori", "Tsukune", "Chicken Skin", "Udon", "Rice Ball"],
        "kiraku": ["Ramen", "Karaage", "Gyoza", "Curry Rice"],
        "shan dong": ["Hand-Pulled Noodles", "Dumplings", "Green Onion Pancake", "Mapo Tofu"],
        "great china": ["Peking Duck", "Double Skin", "Twice-Cooked Pork", "Sizzling Rice Soup"],
        "commis": ["Tasting Menu", "Seasonal Course", "Amuse-Bouche"],
        "horn barbecue": ["Brisket", "Ribs", "Pulled Pork", "Mac & Cheese", "Cornbread"],
        "benchmark pizzeria": ["Margherita Pizza", "Pepperoni Pizza", "Seasonal Pizza"],
        "ramen shop": ["Shoyu Ramen", "Mazemen", "Chicken Ramen", "Pork Bun"],
        "daughter's diner": ["Biscuits & Gravy", "Fried Chicken Sandwich", "Grits"],
        "pyeong chang tofu house": ["Sundubu Jjigae", "Bibimbap", "Bulgogi", "Kimchi Jjigae"],
        "ohgane": ["Galbi", "Bulgogi", "Kimchi Jjigae", "Japchae", "Haemul Pajeon"],
        "koreana plaza": ["Bibimbap", "Galbi", "Kimchi Jjigae", "Japchae"],
        "cholita linda": ["Fish Tacos", "Carne Asada Plate", "Plantain Bowl", "Elote"],
        "tacos sinaloa": ["Al Pastor Taco", "Carne Asada Taco", "Super Burrito", "Carnitas Taco"],
        "grocery cafe": ["Boat Noodles", "Pad Kra Pao", "Mango Sticky Rice", "Papaya Salad"],
        "burma superstar": ["Tea Leaf Salad", "Rainbow Salad", "Platha", "Coconut Chicken Noodles"],
        "spice": ["Tea Leaf Salad", "Mango Noodles", "Coconut Curry Noodles", "Platha"],
        "camino": ["Wood-Fired Meats", "Grilled Vegetables", "Seasonal Salad", "Bread & Butter"],
        "comal": ["Enchiladas", "Tacos Al Pastor", "Guacamole", "Horchata", "Churros"],
        "vik's chaat corner": ["Pani Puri", "Samosa Chaat", "Chole Bhature", "Masala Dosa", "Pav Bhaji"],
        "homeroom": ["Mac & Cheese", "Gilroy Garlic Mac", "Truffle Mac", "Buffalo Mac"],
        "bake sale betty": ["Fried Chicken Sandwich", "Strawberry Shortcake", "Coleslaw"],
        "bakesale betty": ["Fried Chicken Sandwich", "Strawberry Shortcake", "Coleslaw"],
        "fentons creamery": ["Black & Tan Sundae", "Hot Fudge Sundae", "Toasted Almond"],
        "shiba ramen": ["Tonkotsu Ramen", "Spicy Miso Ramen", "Chicken Paitan"],
        "teni east kitchen": ["Mohinga", "Tea Leaf Salad", "Samosa Soup", "Platha"],
        "west berkeley bowl": ["Açaí Bowl", "Smoothie", "Fresh Juice", "Granola Bowl"],
        "alhamra": ["Biryani", "Lamb Nihari", "Seekh Kebab", "Naan", "Haleem"],
        "cabo": ["Ceviche", "Fish Tacos", "Shrimp Cocktail", "Margarita"],
        "shakewell": ["Lamb Meatballs", "Grilled Octopus", "Shakshuka", "Patatas Bravas"],
        "rangoon super stars": ["Tea Leaf Salad", "Mohinga", "Platha", "Coconut Noodles"],
        "la marcha": ["Tapas", "Patatas Bravas", "Croquetas", "Spanish Tortilla", "Paella"],
        "beauty's bagel shop": ["Everything Bagel", "Lox Bagel", "Egg & Cheese", "Schmear Flight"],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // SOUTH BAY / PENINSULA
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Palo Alto / Mountain View / Sunnyvale / Los Altos ────────────
        "tamarine": ["Shaking Beef", "Garlic Noodles", "Crispy Spring Rolls", "Lemongrass Chicken"],
        "evvia": ["Lamb Chops", "Grilled Octopus", "Moussaka", "Spanakopita", "Baklava"],
        "protégé": ["Tasting Menu", "Wagyu", "Foie Gras", "Seasonal Course"],
        "vesta": ["Wood-Fired Pizza", "Burrata", "Meatballs", "Panna Cotta"],
        "ramen nagi": ["Butao King Ramen", "Red King Ramen", "Green King Ramen", "Black King Ramen"],
        "haidilao hot pot": ["Beef Hot Pot", "Lamb Hot Pot", "Mushroom Broth", "Noodle Dance"],
        "din tai fung": ["Xiao Long Bao", "Shrimp & Pork Wontons", "Dan Dan Noodles", "Fried Rice", "Green Beans"],
        "kunjip": ["Galbi", "Bulgogi", "Sundubu Jjigae", "Kimchi Jjigae", "Japchae"],
        "dishdash": ["Lamb Shank", "Falafel", "Hummus", "Shawarma", "Fattoush"],
        "oren's hummus palo alto": ["Hummus", "Falafel", "Shawarma", "Chicken Schnitzel", "Israeli Salad"],
        "rangoon ruby": ["Tea Leaf Salad", "Platha", "Mohinga", "Coconut Chicken Noodles", "Samosa Soup"],
        "zareen's": ["Chicken Biryani", "Seekh Kebab", "Naan", "Chicken Karahi", "Mango Lassi"],
        "santo market": ["Poke Bowl", "Musubi", "Açaí Bowl", "Bento Box"],
        "joanie's cafe": ["French Toast", "Eggs Benedict", "Pancakes", "Breakfast Burrito"],
        "la costanera": ["Ceviche", "Lomo Saltado", "Causa", "Anticuchos", "Pisco Sour"],
        "bird dog": ["Hamachi Crudo", "Duck Breast", "Risotto", "Seasonal Tasting"],
        "sundance the steakhouse": ["Prime Rib", "Filet Mignon", "New York Strip", "Creamed Spinach"],
        "pho ha noi": ["Pho Dac Biet", "Bun Bo Hue", "Banh Mi", "Vermicelli Bowl"],
        "dao fu": ["Mapo Tofu", "Dan Dan Noodles", "Sichuan Boiled Fish", "Chili Wontons"],
        "naschmarkt": ["Wiener Schnitzel", "Spaetzle", "Pretzel", "Apple Strudel"],
        "doppio zero": ["Margherita Pizza", "Burrata", "Risotto", "Tiramisu", "Panna Cotta"],

        // ── San Jose / Santa Clara / Campbell ────────────────────────────
        "luna mexican kitchen": ["Street Tacos", "Enchiladas", "Churros", "Guacamole"],
        "adega": ["Bacalhau", "Caldo Verde", "Francesinha", "Pastel de Nata"],
        "the table": ["Tasting Menu", "Seasonal Course", "Wagyu"],
        "bun bo hue an nam": ["Bun Bo Hue", "Pho", "Banh Mi", "Spring Rolls"],
        "pho y #1": ["Pho Tai", "Pho Dac Biet", "Bun Bo Hue", "Banh Mi"],
        "com tam thien huong": ["Com Tam", "Broken Rice Plate", "Grilled Pork", "Spring Rolls"],
        "smoking pig bbq": ["Brisket", "Pulled Pork", "Tri-Tip", "Mac & Cheese", "Cornbread"],
        "back a yard": ["Jerk Chicken", "Oxtail", "Rice & Peas", "Plantains", "Festival"],
        "lee's sandwiches": ["Banh Mi Thit Nguoi", "Banh Mi Ga", "Vietnamese Coffee", "Che"],
        "falafel's drive-in": ["Falafel Wrap", "Banana Shake", "Hummus Plate", "Gyro"],
        "henry's hi-life": ["BBQ Baby Back Ribs", "Steak", "Garlic Bread", "Caesar Salad"],
        "ramen taka": ["Tonkotsu Ramen", "Tsukemen", "Chashu Don", "Gyoza"],
        "nick the greek": ["Gyro Plate", "Chicken Souvlaki", "Greek Salad", "Baklava"],
        "iguanas": ["Burrito", "Carne Asada Tacos", "Nachos", "Fish Tacos"],
        "la victoria taqueria": ["Orange Sauce Burrito", "Carne Asada Taco", "Super Nachos"],
        "okayama sushi": ["Sashimi Combo", "Bento Box", "Dragon Roll", "Miso Soup"],
        "san pedro square market": ["Craft Beer", "Tacos", "Pizza", "Poke Bowl", "BBQ"],
        "sumiya": ["Yakitori", "Ramen", "Gyoza", "Chicken Karaage", "Edamame"],

        // ── Milpitas / Fremont / Cupertino / Newark ──────────────────────
        "sichuan chili": ["Mapo Tofu", "Sichuan Boiled Fish", "Dan Dan Noodles", "Chili Wontons"],
        "auntie guan's kitchen": ["Dan Dan Noodles", "Wontons in Chili Oil", "Mapo Tofu", "Spicy Chicken"],
        "koi palace": ["Har Gow", "Siu Mai", "Peking Duck", "XO Rice Noodle Roll", "Egg Tart"],
        "h.a.n.d.s new york pizza": ["Cheese Pizza", "Pepperoni Slice", "Garlic Knots"],
        "pakwan": ["Chicken Biryani", "Lamb Karahi", "Naan", "Nihari", "Seekh Kebab"],
        "shalimar": ["Chicken Tikka", "Lamb Biryani", "Garlic Naan", "Nihari", "Haleem"],
        "the cheese steak shop": ["Original Cheese Steak", "Chicken Cheese Steak", "Fries"],
        "sala thai": ["Pad Thai", "Green Curry", "Mango Sticky Rice", "Tom Yum"],
        "lions super": ["Hand-Pulled Noodles", "Lamb Skewers", "Cumin Lamb", "Scallion Pancake"],
        "darda seafood": ["Peking Duck", "Sizzling Rice Soup", "Salt & Pepper Crab", "Walnut Prawns"],
        "great mall food court": ["Pho", "Orange Chicken", "Teriyaki Bowl", "Bubble Tea"],
        "chai pani": ["Vada Pav", "Bhel Puri", "Thali", "Chicken 65", "Masala Chai"],
        "afghani house": ["Kabuli Pulao", "Lamb Kebab", "Mantu", "Bolani", "Green Tea"],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // NORTH BAY / MARIN / NAPA / SONOMA
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "sol food": ["Puerto Rican Chicken", "Plantain Sandwich", "Rice & Beans", "Empanadas"],
        "the french laundry": ["Tasting Menu", "Oysters and Pearls", "Salmon Cornets"],
        "ad hoc": ["Fried Chicken", "Family-Style Dinner", "Buttermilk Biscuits"],
        "bouchon bakery": ["Croissant", "Bouchon", "Macaron", "Nutter Butter"],
        "hog island oyster co": ["Oysters", "Grilled Cheese", "Clam Chowder", "Manila Clams"],
        "nick's cove": ["Oysters", "Clam Chowder", "Fish & Chips", "Crab Cake"],
        "the girl & the fig": ["Fig & Arugula Salad", "Duck Confit", "Steak Frites", "Crème Brûlée"],
        "bottega napa valley": ["Margherita Pizza", "Burrata", "Osso Buco", "Tiramisu"],
        "bistro jeanty": ["Tomato Soup in Puff Pastry", "Duck Confit", "Crème Brûlée", "Coq au Vin"],
        "terrapin crossroads": ["Oysters", "Burger", "Fish Tacos", "Live Music"],
        "fish.": ["Fish Tacos", "Ceviche", "Oysters", "Clam Chowder"],
        "la ginestra": ["Margherita Pizza", "Panna Cotta", "Osso Buco", "Tiramisu"],
        "avatar's": ["Jalapeño Poppers", "Enchiladas", "Indian Curry", "Thai Curry"],
        "burmese kitchen": ["Tea Leaf Salad", "Coconut Noodles", "Samosa Soup", "Platha"],
        "pizzalina": ["Margherita Pizza", "Pepperoni Pizza", "Caesar Salad", "Gelato"],
        "playa": ["Fish Tacos", "Ceviche", "Guacamole", "Carnitas", "Margarita"],
    ]

    /// Look up dishes for a restaurant name (exact or partial match).
    /// Returns nil if no match found.
    static func lookup(_ name: String) -> [String]? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        // Exact match
        if let exact = dishes[key], !exact.isEmpty {
            return exact
        }
        // Partial match — prefer the longest key to avoid false positives
        var bestMatch: [String]? = nil
        var bestMatchLength = 0
        for (dbName, dbDishes) in dishes where !dbDishes.isEmpty {
            if key.contains(dbName) || dbName.contains(key) {
                if dbName.count > bestMatchLength {
                    bestMatch = dbDishes
                    bestMatchLength = dbName.count
                }
            }
        }
        return bestMatch
    }

    /// Returns dishes for a restaurant, falling back to cuisine-based suggestions.
    static func dishes(forRestaurant name: String, cuisine: CuisineType) -> [String] {
        if let knownDishes = lookup(name), !knownDishes.isEmpty {
            return knownDishes
        }
        return PopularDishes.dishes(for: cuisine)
    }
}
