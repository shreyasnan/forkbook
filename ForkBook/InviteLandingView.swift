import SwiftUI

// MARK: - Invite Landing View
//
// First screen a new user sees after tapping an invite link.
// Design: Variant A (Showroom) — see ForkBook-Invite-Landing-Spec.md
//
// This view is designed to work both as a web-bridged landing (via Branch.io)
// and as an in-app preview during development. It is fully parameterized so
// the same view can be rendered server-side for web or client-side in the app.
//
// For v1, this view is standalone and not yet wired into the signup flow.
// Use the #Preview below to iterate on design on device.

struct InviteLandingView: View {

    // MARK: - Inputs

    let inviterName: String
    let inviterInitial: String
    let friendCount: Int
    let placeCount: Int
    let peekRestaurants: [PeekRestaurant]

    var onStart: () -> Void = {}
    var onSignIn: () -> Void = {}

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 48)
                    .padding(.horizontal, 24)

                peekSection
                    .padding(.top, 40)
                    .padding(.horizontal, 20)

                bridgeLine
                    .padding(.top, 24)
                    .padding(.horizontal, 32)

                reassuranceCard
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                ctaStack
                    .padding(.top, 32)
                    .padding(.horizontal, 20)

                footer
                    .padding(.top, 20)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.fbBg.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 20) {
            // Warm-sand avatar, anchoring the page on a person.
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fbWarm, Color(hex: "8a7155")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Text(inviterInitial)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 10) {
                Text("\(inviterName) invited you\nto ForkBook")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(Color.fbText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Restaurant picks from the people you trust.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.fbMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Peek section

    private var peekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("A LOOK AT \(inviterName.uppercased())'S TABLE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color.fbMuted2)

                Text("Her \(friendCount) friends · \(placeCount) places they've loved")
                    .font(.system(size: 13))
                    .foregroundColor(Color.fbMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(peekRestaurants) { restaurant in
                    peekCard(restaurant)
                }
            }
        }
    }

    private func peekCard(_ restaurant: PeekRestaurant) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(restaurant.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.fbText)

            Text("\(restaurant.cuisine) · \(restaurant.neighborhood)")
                .font(.system(size: 12))
                .foregroundColor(Color.fbMuted)

            Text(restaurant.trustSignal)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.fbWarm)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.fbSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.fbBorder, lineWidth: 1)
        )
    }

    // MARK: - Bridge line

    private var bridgeLine: some View {
        Text("This is the kind of signal you'll start seeing.")
            .font(.system(size: 14))
            .italic()
            .foregroundColor(Color.fbMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Reassurance card

    private var reassuranceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(inviterName)'s in your table — you're in hers")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.fbTextLight)

            Text("Add more people you trust, remove anyone anytime. No strangers, no public reviews, no ads.")
                .font(.system(size: 13))
                .foregroundColor(Color.fbMuted)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fbWarm.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.fbWarm.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 14) {
            Button(action: onStart) {
                Text("Start my table")
            }
            .buttonStyle(InviteCTAButtonStyle())

            Button(action: onSignIn) {
                Text("Already on ForkBook? Sign in")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.fbMuted)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("By tapping Start my table, you agree to ForkBook's Terms and Privacy Policy.")
            .font(.system(size: 11))
            .foregroundColor(Color.fbMuted2)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
    }
}

// MARK: - Invite CTA Button Style
//
// Warm-sand primary for the invite landing. Intentionally different from
// FBPrimaryButtonStyle (orange→pink gradient) because the landing's palette
// is built on trust / human signals, not dish energy. See the spec for
// rationale: ForkBook-Invite-Landing-Spec.md.

private struct InviteCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(Color(hex: "1A1208"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Color.fbWarm
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Peek Restaurant Model

struct PeekRestaurant: Identifiable {
    let id = UUID()
    let name: String
    let cuisine: String
    let neighborhood: String
    let trustSignal: String
}

extension PeekRestaurant {
    /// Mock peek restaurants for Pragya's table, used in previews and dev.
    static let mockPragya: [PeekRestaurant] = [
        PeekRestaurant(
            name: "Shizen",
            cuisine: "Japanese",
            neighborhood: "Hayes Valley",
            trustSignal: "Loved by 4 in her table"
        ),
        PeekRestaurant(
            name: "Flour + Water",
            cuisine: "Italian",
            neighborhood: "Mission",
            trustSignal: "Pragya & 2 others loved it"
        ),
        PeekRestaurant(
            name: "Dosa Point",
            cuisine: "South Indian",
            neighborhood: "Sunnyvale",
            trustSignal: "3 people loved this"
        ),
    ]
}

// MARK: - Preview

#Preview("Invite from Pragya") {
    InviteLandingView(
        inviterName: "Pragya",
        inviterInitial: "P",
        friendCount: 5,
        placeCount: 33,
        peekRestaurants: PeekRestaurant.mockPragya,
        onStart: { print("Start my table tapped") },
        onSignIn: { print("Sign in tapped") }
    )
    .preferredColorScheme(.dark)
}
