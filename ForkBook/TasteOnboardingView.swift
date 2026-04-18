import SwiftUI
import FirebaseAuth

// MARK: - Taste Onboarding View

struct TasteOnboardingView: View {
    @ObservedObject private var firestoreService = FirestoreService.shared
    @State private var step = 0  // 0 = cuisines, 1 = frequency, 2 = done
    @State private var selectedCuisines: [CuisineType] = []
    @State private var selectedFrequency: DiningFrequency?
    @State private var isSaving = false

    var onComplete: () -> Void

    // All cuisines except "Other" for cleaner selection
    private var selectableCuisines: [CuisineType] {
        CuisineType.allCases.filter { $0 != .other }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 16)

            switch step {
            case 0:
                cuisineStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 1:
                frequencyStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            default:
                doneStep
                    .transition(.opacity)
            }
        }
        .background(Color.fbBg)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.fbAccent1 : Color.fbBorder)
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Step 0: Cuisine Selection

    private var cuisineStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What do you love to eat?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.fbText)

                Text("Pick your top 3–5 cuisines in order of preference")
                    .font(.subheadline)
                    .foregroundColor(Color.fbMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            // Numbered selection hint
            if !selectedCuisines.isEmpty {
                HStack(spacing: 4) {
                    Text("\(selectedCuisines.count) selected")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.fbAccent1)
                    if selectedCuisines.count < 3 {
                        Text("· pick at least 3")
                            .font(.caption)
                            .foregroundColor(Color.fbMuted2)
                    }
                }
            }

            // Cuisine grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(selectableCuisines) { cuisine in
                    cuisineChip(cuisine)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Next button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = 1
                }
            } label: {
                Text("Next")
            }
            .buttonStyle(FBPrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .disabled(selectedCuisines.count < 3)
            .opacity(selectedCuisines.count < 3 ? 0.5 : 1)
        }
    }

    private func cuisineChip(_ cuisine: CuisineType) -> some View {
        let index = selectedCuisines.firstIndex(of: cuisine)
        let isSelected = index != nil
        let rank = index.map { $0 + 1 }

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if let idx = selectedCuisines.firstIndex(of: cuisine) {
                    selectedCuisines.remove(at: idx)
                } else if selectedCuisines.count < 5 {
                    selectedCuisines.append(cuisine)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let rank {
                    Text("\(rank)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.fbAccent1))
                }

                Text(cuisineEmoji(cuisine))
                    .font(.body)
                Text(cuisine.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.fbAccent1.opacity(0.12) : Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.fbAccent1 : Color.fbBorder, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? Color.fbAccent1 : Color.fbText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 1: Dining Frequency

    private var frequencyStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("How often do you eat out?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.fbText)

                Text("This helps us tune your recommendations")
                    .font(.subheadline)
                    .foregroundColor(Color.fbMuted)
            }

            VStack(spacing: 10) {
                ForEach(DiningFrequency.allCases) { freq in
                    frequencyRow(freq)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Done button
            Button {
                Task {
                    await saveAndComplete()
                }
            } label: {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Let's go!")
                }
            }
            .buttonStyle(FBPrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .disabled(selectedFrequency == nil || isSaving)
            .opacity(selectedFrequency == nil ? 0.5 : 1)
        }
    }

    private func frequencyRow(_ freq: DiningFrequency) -> some View {
        let isSelected = selectedFrequency == freq

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFrequency = freq
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: freq.icon)
                    .font(.body)
                    .frame(width: 24)

                Text(freq.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(Color.fbAccent1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.fbAccent1.opacity(0.12) : Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.fbAccent1 : Color.fbBorder, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? Color.fbAccent1 : Color.fbText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Done Step

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.fbGreen.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.fbGreen)
            }

            Text("You're all set!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.fbText)

            Text("We'll use your preferences to recommend the perfect spots.")
                .font(.subheadline)
                .foregroundColor(Color.fbMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Start exploring")
            }
            .buttonStyle(FBPrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Save

    private func saveAndComplete() async {
        isSaving = true
        let prefs = TastePreferences(
            favoriteCuisines: selectedCuisines,
            diningFrequency: selectedFrequency,
            onboardingCompleted: true
        )
        try? await firestoreService.saveTastePreferences(prefs)
        isSaving = false
        withAnimation(.easeInOut(duration: 0.3)) {
            step = 2
        }
    }

    // MARK: - Helpers

    private func cuisineEmoji(_ cuisine: CuisineType) -> String {
        switch cuisine {
        case .japanese: return "🍣"
        case .chinese: return "🥟"
        case .korean: return "🍜"
        case .thai: return "🌶️"
        case .vietnamese: return "🍲"
        case .indian: return "🍛"
        case .italian: return "🍝"
        case .french: return "🥐"
        case .mexican: return "🌮"
        case .mediterranean: return "🥗"
        case .american: return "🍔"
        case .other: return "🍽️"
        }
    }
}

// MARK: - Edit Preferences View (reusable from Profile)

struct EditPreferencesView: View {
    @ObservedObject private var firestoreService = FirestoreService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCuisines: [CuisineType]
    @State private var selectedFrequency: DiningFrequency?
    @State private var isSaving = false

    init(current: TastePreferences) {
        _selectedCuisines = State(initialValue: current.favoriteCuisines)
        _selectedFrequency = State(initialValue: current.diningFrequency)
    }

    private var selectableCuisines: [CuisineType] {
        CuisineType.allCases.filter { $0 != .other }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Cuisine section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Cuisines")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.fbText)

                        Text("Tap to select your top 3–5 in order")
                            .font(.caption)
                            .foregroundColor(Color.fbMuted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(selectableCuisines) { cuisine in
                                editCuisineChip(cuisine)
                            }
                        }
                    }

                    // Frequency section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dining Frequency")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.fbText)

                        ForEach(DiningFrequency.allCases) { freq in
                            editFrequencyRow(freq)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.fbBg)
            .navigationTitle("Taste Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.fbText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.fbAccent1)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(Color.fbAccent1)
                    .disabled(selectedCuisines.count < 3 || selectedFrequency == nil || isSaving)
                }
            }
        }
    }

    private func editCuisineChip(_ cuisine: CuisineType) -> some View {
        let index = selectedCuisines.firstIndex(of: cuisine)
        let isSelected = index != nil
        let rank = index.map { $0 + 1 }

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if let idx = selectedCuisines.firstIndex(of: cuisine) {
                    selectedCuisines.remove(at: idx)
                } else if selectedCuisines.count < 5 {
                    selectedCuisines.append(cuisine)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let rank {
                    Text("\(rank)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.fbAccent1))
                }

                Text(cuisine.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.fbAccent1.opacity(0.12) : Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.fbAccent1 : Color.fbBorder, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? Color.fbAccent1 : Color.fbText)
        }
        .buttonStyle(.plain)
    }

    private func editFrequencyRow(_ freq: DiningFrequency) -> some View {
        let isSelected = selectedFrequency == freq

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFrequency = freq
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: freq.icon)
                    .font(.body)
                    .frame(width: 24)
                Text(freq.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(Color.fbAccent1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.fbAccent1.opacity(0.12) : Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.fbAccent1 : Color.fbBorder, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? Color.fbAccent1 : Color.fbText)
        }
        .buttonStyle(.plain)
    }

    private func save() async {
        isSaving = true
        let prefs = TastePreferences(
            favoriteCuisines: selectedCuisines,
            diningFrequency: selectedFrequency,
            onboardingCompleted: true
        )
        try? await firestoreService.saveTastePreferences(prefs)
        isSaving = false
        dismiss()
    }
}
