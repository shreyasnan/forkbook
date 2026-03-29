import SwiftUI

struct VisitedListView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var showingShareSheet = false

    var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return store.visitedRestaurants
        }
        return store.visitedRestaurants.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.cuisine.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.visitedRestaurants.isEmpty {
                    emptyState
                } else {
                    restaurantList
                }
            }
            .background(Color.igBlack)
            .scrollContentBackground(.hidden)
            .navigationTitle("My Restaurants")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.visitedRestaurants.isEmpty {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.igTextPrimary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.igTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(category: .visited)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(text: store.shareText(for: .visited))
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.igTextTertiary)
            Text("No restaurants yet")
                .font(.title3)
                .foregroundStyle(Color.igTextSecondary)
            Text("Tap + to add a restaurant you've visited")
                .font(.subheadline)
                .foregroundStyle(Color.igTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.igBlack)
    }

    private var restaurantList: some View {
        List {
            ForEach(filteredRestaurants) { restaurant in
                NavigationLink {
                    EditRestaurantView(restaurant: restaurant)
                } label: {
                    RestaurantRow(restaurant: restaurant)
                }
                .listRowBackground(Color.igSurface)
            }
            .onDelete { offsets in
                store.delete(at: offsets, in: filteredRestaurants)
            }
        }
        .searchable(text: $searchText, prompt: "Search restaurants")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Restaurant Row

struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(restaurant.name)
                    .font(.headline)
                    .foregroundStyle(Color.igTextPrimary)
                Spacer()
                if restaurant.rating > 0 {
                    StarRatingDisplay(rating: restaurant.rating)
                }
            }

            if !restaurant.address.isEmpty {
                Label(restaurant.address, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(Color.igTextTertiary)
                    .lineLimit(1)
            }

            HStack {
                CapsuleTag(text: restaurant.cuisine.rawValue, color: .igGradientOrange)

                if !restaurant.notes.isEmpty {
                    Text(restaurant.notes)
                        .font(.caption)
                        .foregroundStyle(Color.igTextSecondary)
                        .lineLimit(1)
                }
            }

            if !restaurant.dishes.isEmpty {
                DishTagsCompact(dishes: restaurant.dishes)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VisitedListView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
