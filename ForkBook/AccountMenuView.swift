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

// MARK: - Burger Menu Button
//
// Top-right header affordance that opens the Account menu. Used by every
// tab so the Account hub is reachable from anywhere in the app, not just
// Home. Keeps the icon weight/size identical across tabs.

struct BurgerMenuButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.fbText)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Account Menu Presenter
//
// View modifier that hangs the Account menu off any view as a sheet. The
// AccountMenuView uses NavigationLinks internally (Edit Profile, Manage
// Table, etc.) so it MUST be wrapped in a NavigationStack — that's done
// here so each tab doesn't have to wire its own. Sheet presentation
// (vs. pushing onto the host's NavigationStack) keeps the behavior
// identical across tabs that don't all have a NavigationStack at the
// root, and matches the "modal settings" convention users expect.

struct AccountMenuPresenter: ViewModifier {
    @Binding var isPresented: Bool
    var store: RestaurantStore

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    AccountMenuView()
                        .environmentObject(store)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { isPresented = false }
                                    .foregroundColor(Color.fbText)
                            }
                        }
                }
            }
    }
}

extension View {
    /// Attach the Account menu sheet to any view. Pass the same `@State`
    /// binding the BurgerMenuButton flips so tapping the icon presents
    /// the menu.
    func accountMenu(isPresented: Binding<Bool>, store: RestaurantStore) -> some View {
        modifier(AccountMenuPresenter(isPresented: isPresented, store: store))
    }
}
