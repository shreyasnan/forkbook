import SwiftUI
import FirebaseAuth

// MARK: - Manage Table View
//
// Administrative surface for the user's table. Deliberately separate from
// the Table tab: Table tab is for browsing activity and recommendations;
// ManageTableView is for membership + invite link admin.
//
// Contents:
//   1. Your invite link card (copy + share)
//   2. Members list with remove affordance
//
// Notes:
// - `removeMember` currently just updates local state; wiring the
//   Firestore removal is a follow-up (see TODO).

struct ManageTableView: View {
    @EnvironmentObject var store: RestaurantStore
    @ObservedObject private var firestoreService = FirestoreService.shared

    @State private var circle: FirestoreService.Circle?
    @State private var members: [FirestoreService.CircleMember] = []
    @State private var isLoading = true

    @State private var copiedToast = false
    @State private var showShareSheet = false
    @State private var memberPendingRemoval: FirestoreService.CircleMember?

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    private var friends: [FirestoreService.CircleMember] {
        members.filter { $0.uid != currentUid }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                inviteSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                membersSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color.fbBg)
        .navigationTitle("Manage Table")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if copiedToast {
                FBToast(message: "Invite link copied")
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let circle {
                ShareSheet(text: inviteMessage(for: circle))
            }
        }
        .confirmationDialog(
            memberPendingRemoval.map {
                "Remove \($0.displayName) from your table?"
            } ?? "",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let m = memberPendingRemoval { removeMember(m) }
                memberPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                memberPendingRemoval = nil
            }
        } message: {
            Text("They won't be notified. You can re-invite them anytime.")
        }
        .task {
            await loadTable()
        }
    }

    // MARK: - Invite Section

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR INVITE LINK")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.fbMuted2)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 14) {
                Text("Share this with people you trust for food.")
                    .font(.subheadline)
                    .foregroundColor(Color.fbMuted)

                HStack(spacing: 10) {
                    Button {
                        copyInviteLink()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                                .font(.subheadline)
                            Text("Copy link")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Color.fbText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.fbWarm.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(circle == nil)

                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline)
                            Text("Share")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Color.fbText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.fbSurfaceLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.fbBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(circle == nil)
                }

                if let code = circle?.inviteCode {
                    Text("Or enter code: \(code)")
                        .font(.caption)
                        .foregroundColor(Color.fbMuted2)
                }
            }
            .padding(16)
            .background(Color.fbSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MEMBERS · \(friends.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.fbMuted2)
                    .tracking(0.5)
                Spacer()
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.fbMuted)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else if friends.isEmpty {
                Text("Your table is just you right now. Invite someone above to get started.")
                    .font(.subheadline)
                    .foregroundColor(Color.fbMuted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fbSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 1) {
                    ForEach(friends) { member in
                        memberRow(member)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func memberRow(_ member: FirestoreService.CircleMember) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: member.displayName, size: 36)

            Text(member.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.fbText)

            Spacer()

            Button {
                memberPendingRemoval = member
            } label: {
                Text("Remove")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.fbRed.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().stroke(Color.fbRed.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.fbSurface)
    }

    // MARK: - Actions

    private func copyInviteLink() {
        guard let circle else { return }
        UIPasteboard.general.string = inviteMessage(for: circle)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { copiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.3)) { copiedToast = false }
        }
    }

    private func inviteMessage(for circle: FirestoreService.Circle) -> String {
        DeepLinkManager.makeInviteMessage(
            circleName: circle.name,
            code: circle.inviteCode
        )
    }

    private func removeMember(_ member: FirestoreService.CircleMember) {
        // Optimistic local removal; wire Firestore removal in a follow-up.
        members.removeAll { $0.uid == member.uid }
        // TODO: call firestoreService.removeCircleMember(uid: member.uid, circleId: circle?.id)
    }

    // MARK: - Loading

    private func loadTable() async {
        let circles = await firestoreService.getMyCircles()
        guard let first = circles.first else {
            isLoading = false
            return
        }
        circle = first
        members = await firestoreService.getCircleMembers(circle: first)
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ManageTableView()
            .environmentObject(RestaurantStore())
    }
    .preferredColorScheme(.dark)
}
