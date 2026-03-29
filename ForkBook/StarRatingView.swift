import SwiftUI

// MARK: - Reusable Star Rating Component

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 24
    var interactive: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.igGradientYellow : Color.igDivider)
                    .onTapGesture {
                        if interactive {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                rating = (rating == star) ? star - 1 : star
                            }
                        }
                    }
            }
        }
    }
}

// Read-only variant for list rows
struct StarRatingDisplay: View {
    let rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.igGradientYellow : Color.igDivider)
            }
        }
    }
}

#Preview {
    @Previewable @State var rating = 3
    VStack(spacing: 20) {
        StarRatingView(rating: $rating, size: 32)
        StarRatingDisplay(rating: 4)
    }
    .padding()
    .background(Color.igBlack)
    .preferredColorScheme(.dark)
}
