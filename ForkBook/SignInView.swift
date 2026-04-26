import SwiftUI
import AuthenticationServices

// MARK: - Sign In View

struct SignInView: View {
    @ObservedObject var authService = AuthService.shared

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Wordmark — matches LaunchScreenView so the sign-in
                // moment is a continuation of the splash, not a hard
                // visual change.
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

                Spacer()

                VStack(spacing: 12) {
                    // Apple Sign-In Button
                    SignInWithAppleButton(.signIn) { request in
                        let appleRequest = authService.prepareAppleSignIn()
                        request.requestedScopes = appleRequest.requestedScopes
                        request.nonce = appleRequest.nonce
                    } onCompletion: { result in
                        Task {
                            await authService.handleAppleSignIn(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 40)

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.fbRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()
                    .frame(height: 50)
            }
        }
    }
}

#Preview {
    SignInView()
        .preferredColorScheme(.dark)
}
