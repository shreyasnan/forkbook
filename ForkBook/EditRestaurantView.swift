import SwiftUI

struct EditRestaurantView: View {
    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) var dismiss

    let restaurant: Restaurant

    @StateObject private var searchService = RestaurantSearchService()
    @State private var name: String
    @State private var address: String
    @State private var cuisine: CuisineType
    @State private var rating: Int
    @State private var notes: String
    @State private var recommendedBy: String
    @State private var dishes: [DishItem]
    @State private var showSuggestions = false
    @State private var showingDeleteAlert = false
    @State private var showingMoveAlert = false

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        _name = State(initialValue: restaurant.name)
        _address = State(initialValue: restaurant.address)
        _cuisine = State(initialValue: restaurant.cuisine)
        _rating = State(initialValue: restaurant.rating)
        _notes = State(initialValue: restaurant.notes)
        _recommendedBy = State(initialValue: restaurant.recommendedBy)
        _dishes = State(initialValue: restaurant.dishes)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != restaurant.name ||
        address != restaurant.address ||
        cuisine != restaurant.cuisine ||
        rating != restaurant.rating ||
        notes != restaurant.notes ||
        recommendedBy != restaurant.recommendedBy ||
        dishes != restaurant.dishes
    }

    var body: some View {
        Form {
            Section {
                TextField("Restaurant name", text: $searchService.searchText)
                    .font(.title3)
                    .foregroundStyle(Color.igTextPrimary)
                    .onChange(of: searchService.searchText) { _, newValue in
                        name = newValue
                        showSuggestions = true
                    }

                if showSuggestions && !searchService.suggestions.isEmpty {
                    ForEach(searchService.suggestions) { suggestion in
                        Button {
                            name = suggestion.name
                            address = suggestion.subtitle
                            searchService.searchText = suggestion.name
                            showSuggestions = false
                            // Auto-detect cuisine from restaurant name
                            if let detected = CuisineDetector.detect(name: suggestion.name, subtitle: suggestion.subtitle) {
                                cuisine = detected
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(Color.igGradientPink)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.igTextPrimary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Color.igTextTertiary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            } header: {
                Text("Name")
                    .foregroundStyle(Color.igTextSecondary)
            } footer: {
                if !address.isEmpty {
                    Label(address, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(Color.igBlue)
                }
            }
            .listRowBackground(Color.igSurface)

            Section {
                Picker("Cuisine", selection: $cuisine) {
                    ForEach(CuisineType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.igTextPrimary)
                .tint(Color.igBlue)
            }
            .listRowBackground(Color.igSurface)

            if restaurant.category == .visited {
                Section {
                    HStack {
                        Text("Your rating")
                            .foregroundStyle(Color.igTextSecondary)
                        Spacer()
                        StarRatingView(rating: $rating, size: 28)
                    }
                }
                .listRowBackground(Color.igSurface)
            }

            if restaurant.category == .wishlist {
                Section {
                    TextField("Who recommended this?", text: $recommendedBy)
                        .foregroundStyle(Color.igTextPrimary)
                } header: {
                    Text("Recommended by")
                        .foregroundStyle(Color.igTextSecondary)
                }
                .listRowBackground(Color.igSurface)
            }

            // Dishes (liked / disliked)
            Section {
                DishInputRow(dishes: $dishes)
                DishListRows(dishes: $dishes)
            } header: {
                Text("Dishes")
                    .foregroundStyle(Color.igTextSecondary)
            } footer: {
                Text("Type a dish name, then tap 👍 or 👎")
                    .foregroundStyle(Color.igTextTertiary)
            }
            .listRowBackground(Color.igSurface)

            Section {
                TextField("Any notes?", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(Color.igTextPrimary)
            } header: {
                Text("Notes")
                    .foregroundStyle(Color.igTextSecondary)
            }
            .listRowBackground(Color.igSurface)

            // Move between lists
            Section {
                if restaurant.category == .wishlist {
                    Button {
                        showingMoveAlert = true
                    } label: {
                        Label("I've been here! Move to My Restaurants", systemImage: "fork.knife")
                            .foregroundStyle(Color.igBlue)
                    }
                } else {
                    Button {
                        showingMoveAlert = true
                    } label: {
                        Label("Move to Wishlist", systemImage: "star.bubble")
                            .foregroundStyle(Color.igBlue)
                    }
                }
            }
            .listRowBackground(Color.igSurface)

            // Delete
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Restaurant", systemImage: "trash")
                        .foregroundStyle(Color.igRed)
                }
            }
            .listRowBackground(Color.igSurface)
        }
        .background(Color.igBlack)
        .scrollContentBackground(.hidden)
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.semibold)
                .foregroundColor(isValid && hasChanges ? Color.igBlue : Color.igTextTertiary)
                .disabled(!isValid || !hasChanges)
            }
        }
        .onAppear {
            searchService.searchText = restaurant.name
            showSuggestions = false
        }
        .alert("Delete Restaurant", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                store.delete(restaurant)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(restaurant.name)?")
        }
        .alert("Move Restaurant", isPresented: $showingMoveAlert) {
            Button("Move") {
                moveRestaurant()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let destination = restaurant.category == .wishlist ? "My Restaurants" : "Wishlist"
            Text("Move \(restaurant.name) to \(destination)?")
        }
    }

    private func saveChanges() {
        var updated = restaurant
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.address = address.trimmingCharacters(in: .whitespaces)
        updated.cuisine = cuisine
        updated.rating = rating
        updated.notes = notes.trimmingCharacters(in: .whitespaces)
        updated.recommendedBy = recommendedBy.trimmingCharacters(in: .whitespaces)
        updated.dishes = dishes
        store.update(updated)
        dismiss()
    }

    private func moveRestaurant() {
        var updated = restaurant
        updated.category = restaurant.category == .visited ? .wishlist : .visited
        if updated.category == .visited && updated.rating == 0 {
            updated.rating = 3
        }
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.address = address.trimmingCharacters(in: .whitespaces)
        updated.cuisine = cuisine
        updated.notes = notes.trimmingCharacters(in: .whitespaces)
        updated.recommendedBy = recommendedBy.trimmingCharacters(in: .whitespaces)
        updated.dishes = dishes
        store.update(updated)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        EditRestaurantView(restaurant: Restaurant(
            name: "Test Restaurant",
            address: "123 Main St, San Francisco, CA",
            cuisine: .italian,
            category: .visited,
            rating: 4,
            notes: "Great pasta"
        ))
    }
    .environmentObject(RestaurantStore())
    .preferredColorScheme(.dark)
}
