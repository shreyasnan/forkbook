import SwiftUI
import FirebaseAuth

// MARK: - Edit Profile View
//
// Slim identity editor accessed from AccountMenuView. This is the narrow
// replacement for the old ProfileView — photo, display name, username,
// and taste prefs. Stats, "known for", and "table contribution" were
// dropped because they were more useful pointed at other people (they
// now live on member detail pages in the Table tab).

struct EditProfileView: View {
    @EnvironmentObject var store: RestaurantStore
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared

    @State private var profile: FirestoreService.UserProfile?
    @State private var profilePhotoData: Data? = ProfilePhotoStore.shared.load()
    @State private var tastePrefs = TastePreferences()

    @State private var showEditUsername = false
    @State private var showEditPreferences = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {

                // Photo + name header
                photoSection
                    .padding(.top, 16)

                // Identity rows (display name, @username)
                VStack(spacing: 1) {
                    identityRow(
                        icon: "person",
                        label: "Display Name",
                        value: authService.displayName
                    ) {
                        // Display name is owned by the auth provider (Apple/Google)
                        // today; making it editable is a separate change.
                    }
                    .disabled(true)
                    .opacity(0.8)

                    Button {
                        showEditUsername = true
                    } label: {
                        identityRow(
                            icon: "at",
                            label: "Username",
                            value: profile.map { "@\($0.username)" } ?? "@…"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                // Taste preferences
                VStack(spacing: 1) {
                    Button {
                        showEditPreferences = true
                    } label: {
                        identityRow(
                            icon: "sparkles",
                            label: "Taste Preferences",
                            value: tastePrefsSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color.fbBg)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditPreferences, onDismiss: {
            Task { tastePrefs = await firestoreService.getTastePreferences() }
        }) {
            EditPreferencesView(current: tastePrefs)
        }
        .sheet(isPresented: $showEditUsername, onDismiss: {
            Task {
                profile = await firestoreService.getUserProfile(
                    uid: Auth.auth().currentUser?.uid ?? ""
                )
            }
        }) {
            EditUsernameSheet(
                currentUsername: profile?.username ?? "",
                onSave: { newUsername in
                    Task {
                        try? await firestoreService.updateUsername(newUsername)
                        profile?.username = newUsername
                    }
                }
            )
        }
        .task {
            await loadProfile()
            tastePrefs = await firestoreService.getTastePreferences()
        }
        .onChange(of: profilePhotoData) { _, newValue in
            ProfilePhotoStore.shared.save(newValue)
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 10) {
            ProfilePhotoPicker(
                selectedImageData: $profilePhotoData,
                avatarName: authService.displayName,
                avatarSize: 96
            )

            Text("Tap to update your photo")
                .font(.caption)
                .foregroundColor(Color.fbMuted2)
        }
    }

    // MARK: - Identity Row

    private func identityRow(
        icon: String,
        label: String,
        value: String,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.fbMuted2)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(Color.fbMuted2)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(Color.fbText)
                    .lineLimit(1)
            }

            Spacer()

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Color.fbMuted2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.fbSurface)
    }

    // MARK: - Computed

    private var tastePrefsSummary: String {
        let cuisines = tastePrefs.favoriteCuisines
        if cuisines.isEmpty {
            return "Not set"
        }
        let top = cuisines.prefix(3).map(\.rawValue).joined(separator: ", ")
        if cuisines.count > 3 {
            return "\(top) +\(cuisines.count - 3)"
        }
        return top
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        profile = await firestoreService.getUserProfile(uid: uid)
    }
}

// MARK: - Edit Username Sheet
// (Moved here from the old ProfileView — still only used from EditProfileView.)

struct EditUsernameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentUsername: String
    let onSave: (String) -> Void

    @State private var username: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.fbAccent1.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "at")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.fbAccent1)
                }

                Text("Edit Username")
                    .font(.title2.bold())
                    .foregroundColor(Color.fbText)

                HStack {
                    Text("@")
                        .font(.title2.monospaced())
                        .foregroundColor(Color.fbMuted)
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced())
                        .foregroundColor(Color.fbText)
                }
                .padding()
                .background(Color.fbSurfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.fbBorder, lineWidth: 1)
                )
                .padding(.horizontal, 40)

                Button {
                    isSaving = true
                    let cleaned = username.lowercased().filter { $0.isLetter || $0.isNumber }
                    onSave(cleaned)
                    dismiss()
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(FBPrimaryButtonStyle())
                .padding(.horizontal, 40)
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
                Spacer()
            }
            .background(Color.fbBg)
            .onAppear {
                username = currentUsername
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.fbText)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(RestaurantStore())
    }
    .preferredColorScheme(.dark)
}
