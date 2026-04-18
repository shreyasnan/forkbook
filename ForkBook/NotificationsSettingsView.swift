import SwiftUI

// MARK: - Notifications Settings View
//
// Greenfield stub. None of these toggles are wired to the notification
// system yet — they're scaffolding so the surface exists and we can start
// routing real toggles through it as they get built.
//
// State is persisted to UserDefaults for now so toggles survive app restarts
// during development. Swap for a real backend preference store when
// notifications actually ship.

struct NotificationsSettingsView: View {

    @AppStorage("notif.someoneJoinsTable")   private var someoneJoinsTable = true
    @AppStorage("notif.friendLogsRestaurant") private var friendLogsRestaurant = true
    @AppStorage("notif.weeklyDigest")         private var weeklyDigest = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(spacing: 1) {
                    toggleRow(
                        icon: "person.badge.plus",
                        label: "Someone joins my table",
                        sublabel: "When a person you invited accepts.",
                        isOn: $someoneJoinsTable
                    )

                    toggleRow(
                        icon: "fork.knife",
                        label: "A friend logs a restaurant",
                        sublabel: "Activity from people in your table.",
                        isOn: $friendLogsRestaurant
                    )

                    toggleRow(
                        icon: "envelope",
                        label: "Weekly digest",
                        sublabel: "Sunday recap of what your table loved this week.",
                        isOn: $weeklyDigest
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                Text("You can always change these later. System-level notification permission is managed in iOS Settings.")
                    .font(.caption)
                    .foregroundColor(Color.fbMuted2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .background(Color.fbBg)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Toggle Row

    private func toggleRow(
        icon: String,
        label: String,
        sublabel: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.fbMuted2)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.fbText)
                Text(sublabel)
                    .font(.caption)
                    .foregroundColor(Color.fbMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.fbAccent1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.fbSurface)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
    .preferredColorScheme(.dark)
}
