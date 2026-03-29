import SwiftUI

struct AddRestaurantView: View {
    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) var dismiss

    let category: RestaurantCategory

    @StateObject private var searchService = RestaurantSearchService()
    @State private var name = ""
    @State private var address = ""
    @State private var cuisine: CuisineType = .other
    @State private var rating: Int = 0
    @State private var notes = ""
    @State private var recommendedBy = ""
    @State private var dishes: [DishItem] = []
    @State private var showSuggestions = true

    @FocusState private var nameFieldFocused: Bool

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name with autocomplete
                Section {
                    TextField("Start typing a restaurant name...", text: $searchService.searchText)
                        .font(.title3)
                        .foregroundStyle(Color.igTextPrimary)
                        .focused($nameFieldFocused)
                        .submitLabel(.next)
                        .onChange(of: searchService.searchText) { _, newValue in
                            name = newValue
                            showSuggestions = true
                        }

                    // Autocomplete suggestions
                    if showSuggestions && !searchService.suggestions.isEmpty {
                        ForEach(searchService.suggestions) { suggestion in
                            Button {
                                selectSuggestion(suggestion)
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

                    if searchService.isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.igTextTertiary)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(Color.igTextTertiary)
                        }
                    }
                } header: {
                    Text("Restaurant")
                        .foregroundStyle(Color.igTextSecondary)
                } footer: {
                    if !address.isEmpty {
                        Label(address, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(Color.igBlue)
                    }
                }
                .listRowBackground(Color.igSurface)

                // Cuisine picker
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

                // Rating (only for visited restaurants)
                if category == .visited {
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

                // Recommended by (only for wishlist)
                if category == .wishlist {
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
                if category == .visited {
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
                }

                // Notes
                Section {
                    TextField("Any notes? (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(Color.igTextPrimary)
                } header: {
                    Text("Notes")
                        .foregroundStyle(Color.igTextSecondary)
                }
                .listRowBackground(Color.igSurface)
            }
            .background(Color.igBlack)
            .scrollContentBackground(.hidden)
            .navigationTitle(category == .visited ? "Add Restaurant" : "Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.igTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRestaurant()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? Color.igBlue : Color.igTextTertiary)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                nameFieldFocused = true
            }
        }
        .preferredColorScheme(.dark)
    }

    private func selectSuggestion(_ suggestion: RestaurantSearchService.RestaurantSuggestion) {
        name = suggestion.name
        address = suggestion.subtitle
        searchService.searchText = suggestion.name
        showSuggestions = false

        // Auto-detect cuisine from the restaurant name
        if let detected = CuisineDetector.detect(name: suggestion.name, subtitle: suggestion.subtitle) {
            cuisine = detected
        }
    }

    private func saveRestaurant() {
        let restaurant = Restaurant(
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            cuisine: cuisine,
            category: category,
            rating: category == .visited ? rating : 0,
            notes: notes.trimmingCharacters(in: .whitespaces),
            recommendedBy: recommendedBy.trimmingCharacters(in: .whitespaces),
            dishes: dishes
        )
        store.add(restaurant)
        dismiss()
    }
}

#Preview {
    AddRestaurantView(category: .visited)
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
