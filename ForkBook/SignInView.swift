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

                // Logo
                ZStack {
                    Circle()
                        .fill(Color.fbAccent1)
                        .frame(width: 88, height: 88)

                    Image(systemName: "fork.knife")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    Text("ForkBook")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color.fbText)

                    Text("Discover restaurants through\npeople you trust")
                        .font(.subheadline)
                        .foregroundColor(Color.fbMuted)
                        .multilineTextAlignment(.center)
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
