import SwiftUI

// MARK: - Launch Screen View
//
// The SwiftUI splash shown on top of the iOS launch image for ~2.2s on
// cold start, and again while AuthService is resolving signed-in state.
// Hold duration is set in ForkBookApp.swift's .onAppear.
//
// Design intent: wordmark-only, no icon. The real iOS launch image
// carries the app icon moment; this layer is the brand "handshake" —
// quiet, confident, and it states what the product is before the UI loads.
//
// Treatment:
//   - "ForkBook" wordmark in warm-sand, oversized, slightly tracked
//   - A thin warm-sand rule below, sized as a mark detail
//   - Uppercase tracked caption: "WHERE YOUR TABLE EATS"
//   - Gentle fade + subtle rise on appear — no spring bounce

struct LaunchScreenView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.fbBg
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("ForkBook")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color.fbWarm)

                Rectangle()
                    .fill(Color.fbWarm.opacity(0.45))
                    .frame(width: 36, height: 1.5)

                Text("WHERE YOUR TABLE EATS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Color.fbMuted2)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appeared = true
            }
        }
    }
}

#Preview {
    LaunchScreenView()
        .preferredColorScheme(.dark)
}
