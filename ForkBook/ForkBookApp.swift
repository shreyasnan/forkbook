import SwiftUI

@main
struct ForkBookApp: App {
    @StateObject private var store = RestaurantStore()
    @StateObject private var authService = AuthService.shared
    @State private var showLaunch = true
    @State private var pendingDeepLink: DeepLinkManager.DeepLink?
    @State private var deepLinkToast: String?

    init() {
        FirebaseConfig.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authService.isLoading {
                    LaunchScreenView()
                } else if authService.isSignedIn {
                    ContentView()
                        .environmentObject(store)
                        .preferredColorScheme(.dark)
                        .overlay(alignment: .top) {
                            if let toast = deepLinkToast {
                                deepLinkToastView(toast)
                            }
                        }
                } else {
                    SignInView()
                        .preferredColorScheme(.dark)
                }

                if showLaunch {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Splash holds for 2.2s before starting a 0.4s fade-out.
                // After the 0.55s wordmark fade-in, that leaves ~1.65s
                // of fully-visible time — enough to read the wordmark
                // and "WHERE YOUR TABLE EATS" tagline on first launch.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunch = false
                    }
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: authService.isSignedIn) { _, signedIn in
                if signedIn, let deepLink = pendingDeepLink {
                    processDeepLink(deepLink)
                    pendingDeepLink = nil
                }
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        let deepLink = DeepLinkManager.parse(url: url)
        guard deepLink != .unknown else { return }

        if authService.isSignedIn {
            processDeepLink(deepLink)
        } else {
            pendingDeepLink = deepLink
        }
    }

    private func processDeepLink(_ deepLink: DeepLinkManager.DeepLink) {
        switch deepLink {
        case .joinCircle(let code):
            Task {
                do {
                    let result = try await FirestoreService.shared.acceptInvite(inviteCode: code)
                    if result.alreadyMember {
                        showToast("You're already at \(result.circle.name).")
                    } else {
                        showToast("Joined \(result.circle.name)!")
                    }
                } catch {
                    showToast("Couldn't join table: \(error.localizedDescription)")
                }
            }
        case .unknown:
            break
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.4)) {
            deepLinkToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                deepLinkToast = nil
            }
        }
    }

    @ViewBuilder
    private func deepLinkToastView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.fbGreen)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.fbText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.fbSurface)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(10)
    }
}
