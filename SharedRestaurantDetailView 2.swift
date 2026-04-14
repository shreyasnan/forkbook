import SwiftUI

// MARK: - Shared Restaurant Detail View (read-only view of a friend's restaurant)

struct SharedRestaurantDetailView: View {
    let restaurant: SharedRestaurant

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    // Shared by
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.igGradientPink.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(restaurant.userName.prefix(1)).uppercased())
                                    .font(.caption.bold())
                                    .foregroundColor(Color.igGradientPink)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(restaurant.userName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.igTextPrimary)
                            if let date = restaurant.dateVisited {
                                Text("Visited \(date, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(Color.igTextSecondary)
                            }
                        }
                    }

                    // Restaurant name
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.igTextPrimary)

                    // Address
                    if !restaurant.address.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.igRed)
                            Text(restaurant.address)
                                .font(.subheadline)
                                .foregroundColor(Color.igTextSecondary)
                        }
                    }

                    // Cuisine & rating
                    HStack(spacing: 12) {
                        if restaurant.cuisine != .other {
                            CapsuleTag(text: restaurant.cuisine.rawValue, color: .igGradientOrange)
                        }

                        if restaurant.rating > 0 {
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= restaurant.rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(star <= restaurant.rating ? Color.igGradientYellow : Color.igDivider)
                                }
                            }
                        }

                        if restaurant.visitCount > 1 {
                            CapsuleTag(text: "Visited \(restaurant.visitCount)x", color: .igBlue)
                        }
                    }
                }
                .fbCard()
                .padding(.horizontal, 20)

                // Dishes section
                if !restaurant.dishes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dishes")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.igTextPrimary)

                        // Liked dishes
                        if !restaurant.likedDishes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(Color.igGreen)
                                    Text("Liked")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.igTextPrimary)
                                }

                                ForEach(restaurant.likedDishes, id: \.name) { dish in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.igGreen)
                                            .frame(width: 6, height: 6)
                                        Text(dish.name)
                                            .font(.subheadline)
                                            .foregroundColor(Color.igTextSecondary)
                                    }
                                }
                            }
                        }

                        // Disliked dishes
                        if !restaurant.dislikedDishes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .foregroundColor(Color.igRed)
                                    Text("Didn't like")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.igTextPrimary)
                                }

                                ForEach(restaurant.dislikedDishes, id: \.name) { dish in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.igRed)
                                            .frame(width: 6, height: 6)
                                        Text(dish.name)
                                            .font(.subheadline)
                                            .foregroundColor(Color.igTextSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .fbCard()
                    .padding(.horizontal, 20)
                }

                // Notes
                if !restaurant.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.igTextPrimary)

                        Text(restaurant.notes)
                            .font(.subheadline)
                            .foregroundColor(Color.igTextSecondary)
                            .italic()
                    }
                    .fbCard()
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .background(Color.igBlack)
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
