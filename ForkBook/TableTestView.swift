import SwiftUI

// MARK: - Table Test View (V4 — Utility First)
//
// Three sections, in order:
//   1. Trust for…        -- the core job: who to ask for what
//   2. Your people       -- compact rows, one hint line each
//   3. Changed confidence -- sharp low-volume signal, not a feed

struct TableTestView: View {
    @State private var showInviteSheet = false

    // MARK: Sample Data

    private let trustMap: [TrustPair] = [
        TrustPair(category: "Date night",   person: "Priya"),
        TrustPair(category: "Lunch",        person: "Raj"),
        TrustPair(category: "New spots",    person: "Maya"),
        TrustPair(category: "Group dinner", person: "Ankit")
    ]

    private let people: [TablePerson] = [
        TablePerson(
            initial: "P",
            name: "Priya",
            descriptor: "Polished sushi and special occasions.",
            hint: "You usually agree."
        ),
        TablePerson(
            initial: "R",
            name: "Raj",
            descriptor: "Dependable for lunch and Indian.",
            hint: "Often goes, rarely misses."
        ),
        TablePerson(
            initial: "M",
            name: "Maya",
            descriptor: "Finds places early.",
            hint: "Useful when you want something new."
        ),
        TablePerson(
            initial: "A",
            name: "Ankit",
            descriptor: "Best when a group dinner needs to work.",
            hint: "You've gone to 5 of his picks."
        ),
        TablePerson(
            initial: "L",
            name: "Lena",
            descriptor: "Brunch, pastry, and slower weekends.",
            hint: "You loved 4 of her 6 picks."
        ),
        TablePerson(
            initial: "S",
            name: "Sam",
            descriptor: "Ramen, tacos, late-night food.",
            hint: "You agreed on 6 places."
        )
    ]

    private let signals: [ConfidenceSignal] = [
        ConfidenceSignal(
            name: "Priya",
            action: "marked the omakase amazing again at",
            place: "Ju-Ni",
            timeAgo: "2d"
        ),
        ConfidenceSignal(
            name: "Raj",
            action: "went back to",
            place: "Dosa Point",
            timeAgo: "4d"
        ),
        ConfidenceSignal(
            name: "Maya",
            action: "saved",
            place: "Flour + Water",
            timeAgo: "5d"
        ),
        ConfidenceSignal(
            name: "Ankit",
            action: "booked a table at",
            place: "Cotogna",
            timeAgo: "1w"
        )
    ]

    // MARK: Body

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    trustForSection
                        .padding(.horizontal, 20)

                    yourPeopleSection
                        .padding(.horizontal, 20)

                    changedConfidenceSection
                        .padding(.horizontal, 20)

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InvitePlaceholderSheet()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Table")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.fbText)

                Text("Who should I ask?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showInviteSheet = true
            } label: {
                Text("+ Invite")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.fbWarm.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(Color.fbWarm.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(TableCardPressStyle())
        }
    }

    // MARK: Section 1 — Trust for…

    private var trustForSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TRUST FOR…")

            VStack(spacing: 0) {
                ForEach(Array(trustMap.enumerated()), id: \.offset) { index, pair in
                    TrustShortcutRow(pair: pair)

                    if index < trustMap.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: Section 2 — Your people

    private var yourPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("YOUR PEOPLE")

            VStack(spacing: 10) {
                ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                    CompactPersonRow(person: person)
                }
            }
        }
    }

    // MARK: Section 3 — Changed confidence

    private var changedConfidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CHANGED CONFIDENCE")

            VStack(spacing: 0) {
                ForEach(Array(signals.enumerated()), id: \.offset) { index, item in
                    ConfidenceRow(signal: item)

                    if index < signals.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color(hex: "8E8E93"))
    }
}

// MARK: - Models

private struct TablePerson {
    let initial: String
    let name: String
    let descriptor: String
    let hint: String
}

private struct TrustPair {
    let category: String
    let person: String
}

private struct ConfidenceSignal {
    let name: String
    let action: String
    let place: String
    let timeAgo: String
}

// MARK: - Trust Shortcut Row (section 1)

private struct TrustShortcutRow: View {
    let pair: TrustPair

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Text(pair.category)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fbText)

                Spacer()

                Text("→")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))

                Text(pair.person)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableCardPressStyle())
    }
}

// MARK: - Compact Person Row (section 2)

private struct CompactPersonRow: View {
    let person: TablePerson

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)

                    Text(person.descriptor)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(person.hint)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fbWarm.opacity(0.9))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(TableCardPressStyle())
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.fbWarm.opacity(0.14))

            Circle()
                .stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)

            Text(person.initial)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.fbWarm)
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - Confidence Signal Row (section 3)

private struct ConfidenceRow: View {
    let signal: ConfidenceSignal

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                (
                    Text(signal.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.fbText)
                    +
                    Text(" \(signal.action) ")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                    +
                    Text(signal.place)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.fbWarm)
                )
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(signal.timeAgo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableCardPressStyle())
    }
}

// MARK: - Invite Placeholder Sheet

private struct InvitePlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Invite to your table")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.fbText)

                Text("Your table works best with 3–5 people whose taste you already trust. Share a quick invite via text.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                } label: {
                    Text("Invite by text")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.fbWarm.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(TableCardPressStyle())

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(24)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Press Style

private struct TableCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .brightness(configuration.isPressed ? 0.015 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    TableTestView()
        .preferredColorScheme(.dark)
}
