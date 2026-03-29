import SwiftUI

struct WishlistView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var showingShareSheet = false

    var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return store.wishlistRestaurants
        }
        return store.wishlistRestaurants.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.cuisine.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.recommendedBy.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.wishlistRestaurants.isEmpty {
                    emptyState
                } else {
                    wishlistList
                }
            }
            .background(Color.igBlack)
            .scrollContentBackground(.hidden)
            .navigationTitle("Wishlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.wishlistRestaurants.isEmpty {
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
                AddRestaurantView(category: .wishlist)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(text: store.shareText(for: .wishlist))
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.bubble")
                .font(.system(size: 64))
                .foregroundStyle(Color.igTextTertiary)
            Text("Your wishlist is empty")
                .font(.title3)
                .foregroundStyle(Color.igTextSecondary)
            Text("Tap + to save a recommendation")
                .font(.subheadline)
                .foregroundStyle(Color.igTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.igBlack)
    }

    private var wishlistList: some View {
        List {
            ForEach(filteredRestaurants) { restaurant in
                NavigationLink {
                    EditRestaurantView(restaurant: restaurant)
                } label: {
                    WishlistRow(restaurant: restaurant)
                }
                .listRowBackground(Color.igSurface)
            }
            .onDelete { offsets in
                store.delete(at: offsets, in: filteredRestaurants)
            }
        }
        .searchable(text: $searchText, prompt: "Search wishlist")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Wishlist Row

struct WishlistRow: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(restaurant.name)
                .font(.headline)
                .foregroundStyle(Color.igTextPrimary)

            if !restaurant.address.isEmpty {
                Label(restaurant.address, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(Color.igTextTertiary)
                    .lineLimit(1)
            }

            HStack {
                CapsuleTag(text: restaurant.cuisine.rawValue, color: .igGradientPurple)

                if !restaurant.recommendedBy.isEmpty {
                    Label(restaurant.recommendedBy, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(Color.igTextSecondary)
                }
            }

            if !restaurant.notes.isEmpty {
                Text(restaurant.notes)
                    .font(.caption)
                    .foregroundStyle(Color.igTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WishlistView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
