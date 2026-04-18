import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Auth Service

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    // For Apple Sign-In nonce verification
    private var currentNonce: String?

    static let shared = AuthService()

    private init() {
        // Listen for auth state changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isSignedIn = user != nil
                self?.isLoading = false
            }
        }
    }

    // MARK: - Apple Sign-In

    /// Generate a nonce and return the request for Apple Sign-In
    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Handle the Apple Sign-In result
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to get Apple ID token."
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)

                // Update display name from Apple if available (only sent on first sign-in)
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !displayName.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        try? await changeRequest.commitChanges()
                    }
                }

                // Create/update user profile in Firestore
                await FirestoreService.shared.createUserProfileIfNeeded(for: authResult.user)

                errorMessage = nil
            } catch {
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }

        case .failure(let error):
            // User cancelled is not an error worth showing
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Anonymous Sign-In (for testing without Apple Developer account)

    func signInAnonymously() async {
        do {
            let result = try await Auth.auth().signInAnonymously()
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = "Shreyas"
            try? await changeRequest.commitChanges()
            await FirestoreService.shared.createUserProfileIfNeeded(for: result.user)
            errorMessage = nil
        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = nil
        } catch {
            errorMessage = "Sign-out failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Display Name

    var displayName: String {
        user?.displayName ?? user?.email ?? "User"
    }

    var uid: String? {
        user?.uid
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
