import SwiftUI

// MARK: - Account Menu View
//
// Hub that opens from the top-right icon on Home. Replaces the previous
// self-profile surface, which tried to be a "taste identity" page. We moved
// the useful trust-insight content onto member detail pages (where it helps
// users decide whose rec to trust) and kept only the administrative actions
// here.
//
// Four rows: Edit Profile, Manage Table, Manage Notifications, Sign Out.

struct AccountMenuView: View {
    @EnvironmentObject var store: RestaurantStore
    @ObservedObject private var authService = AuthService.shared

    @State private var showSignOutConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Primary actions group
                VStack(spacing: 1) {
                    NavigationLink {
                        EditProfileView()
                            .environmentObject(store)
                    } label: {
                        accountRow(icon: "person.crop.circle", label: "Edit Profile")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ManageTableView()
                            .environmentObject(store)
                    } label: {
                        accountRow(icon: "person.2", label: "Manage Table")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        accountRow(icon: "bell", label: "Manage Notifications")
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                // Destructive action group
                VStack(spacing: 1) {
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        accountRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            label: "Sign Out",
                            isDestructive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .background(Color.fbBg)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Sign out of ForkBook?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                authService.signOut()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Row

    private func accountRow(
        icon: String,
        label: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isDestructive ? Color.fbRed.opacity(0.8) : Color.fbMuted2)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundColor(isDestructive ? Color.fbRed : Color.fbText)
            Spacer()
            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Color.fbMuted2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.fbSurface)
    }
}

#Preview {
    NavigationStack {
        AccountMenuView()
            .environmentObject(RestaurantStore())
    }
    .preferredColorScheme(.dark)
}
