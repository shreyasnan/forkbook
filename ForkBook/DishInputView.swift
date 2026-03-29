import SwiftUI

// MARK: - Dish Input Row (just the text field + buttons)

struct DishInputRow: View {
    @Binding var dishes: [DishItem]
    @State private var newDishName = ""

    private var canAdd: Bool {
        !newDishName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a dish...", text: $newDishName)
                .font(.subheadline)
                .submitLabel(.done)
                .onSubmit {
                    addDish(liked: true)
                }

            Button {
                addDish(liked: true)
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.body)
                    .foregroundStyle(canAdd ? Color.igGreen : Color.igGreen.opacity(0.3))
            }
            .disabled(!canAdd)
            .buttonStyle(.plain)

            Button {
                addDish(liked: false)
            } label: {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.body)
                    .foregroundStyle(canAdd ? Color.igRed : Color.igRed.opacity(0.3))
            }
            .disabled(!canAdd)
            .buttonStyle(.plain)
        }
    }

    private func addDish(liked: Bool) {
        let trimmed = newDishName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        dishes.append(DishItem(name: trimmed, liked: liked))
        newDishName = ""
    }
}

// MARK: - Dish List Rows (for display inside a Form Section)

struct DishListRows: View {
    @Binding var dishes: [DishItem]

    var body: some View {
        ForEach(dishes) { dish in
            HStack {
                Image(systemName: dish.liked ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .font(.caption)
                    .foregroundStyle(dish.liked ? Color.igGreen : Color.igRed)

                Text(dish.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.igTextPrimary)

                Spacer()

                Button {
                    dishes.removeAll { $0.id == dish.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.igTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Compact display for list rows (read-only)

struct DishTagsCompact: View {
    let dishes: [DishItem]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(dishes.prefix(4)) { dish in
                HStack(spacing: 2) {
                    Image(systemName: dish.liked ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.system(size: 8))
                    Text(dish.name)
                        .font(.caption2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((dish.liked ? Color.igGreen : Color.igRed).opacity(0.12))
                .foregroundStyle(dish.liked ? Color.igGreen : Color.igRed)
                .clipShape(Capsule())
            }

            if dishes.count > 4 {
                Text("+\(dishes.count - 4)")
                    .font(.caption2)
                    .foregroundStyle(Color.igTextTertiary)
            }
        }
    }
}

#Preview {
    @Previewable @State var dishes: [DishItem] = [
        DishItem(name: "Margherita Pizza", liked: true),
        DishItem(name: "Tiramisu", liked: true),
        DishItem(name: "Burnt Risotto", liked: false),
    ]
    Form {
        Section("Dishes") {
            DishInputRow(dishes: $dishes)
            DishListRows(dishes: $dishes)
        }
    }
    .preferredColorScheme(.dark)
}
