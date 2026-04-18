import SwiftUI
import PhotosUI

// MARK: - Avatar View
// Premium initials-based avatar with optional photo overlay.
// Uses a warm gradient derived from the user's name for visual identity.
// Photo is optional and never blocks onboarding.

struct AvatarView: View {
    let name: String
    let size: CGFloat
    var photoData: Data? = nil
    var showEditBadge: Bool = false

    /// Deterministic gradient based on name hash
    private var gradientColors: [Color] {
        let hash = abs(name.hashValue)
        let palettes: [[Color]] = [
            [Color(hex: "667EEA"), Color(hex: "764BA2")],  // indigo → purple
            [Color(hex: "F093FB"), Color(hex: "F5576C")],  // pink → rose
            [Color(hex: "4FACFE"), Color(hex: "00F2FE")],  // sky → cyan
            [Color(hex: "43E97B"), Color(hex: "38F9D7")],  // green → teal
            [Color(hex: "FA709A"), Color(hex: "FEE140")],  // coral → yellow
            [Color(hex: "A18CD1"), Color(hex: "FBC2EB")],  // lavender → blush
            [Color(hex: "FCCB90"), Color(hex: "D57EEB")],  // peach → violet
            [Color(hex: "89F7FE"), Color(hex: "66A6FF")],  // ice → blue
        ]
        return palettes[hash % palettes.count]
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var fontSize: CGFloat {
        if size >= 80 { return size * 0.36 }
        if size >= 48 { return size * 0.38 }
        return size * 0.42
    }

    var body: some View {
        ZStack {
            if let data = photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Gradient initials avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }

            // Edit badge
            if showEditBadge {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.fbAccent1)
                                .frame(width: size * 0.3, height: size * 0.3)
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.13))
                                .foregroundColor(.white)
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.fbBg, lineWidth: 2.5)
                        )
                    }
                }
                .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Avatar with Instagram-style gradient ring

struct RingedAvatarView: View {
    let name: String
    let size: CGFloat
    var photoData: Data? = nil
    var showRing: Bool = true

    var body: some View {
        ZStack {
            if showRing {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.fbAccent2, .fbAccent2, .fbAccent1, .fbAccent1],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size + 6, height: size + 6)
            }

            Circle()
                .fill(Color.fbBg)
                .frame(width: size + 2, height: size + 2)

            AvatarView(name: name, size: size, photoData: photoData)
        }
    }
}

// MARK: - Photo Picker Helper

struct ProfilePhotoPicker: View {
    @Binding var selectedImageData: Data?
    @State private var showActionSheet = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?

    let avatarName: String
    let avatarSize: CGFloat

    var body: some View {
        Button {
            showActionSheet = true
        } label: {
            AvatarView(
                name: avatarName,
                size: avatarSize,
                photoData: selectedImageData,
                showEditBadge: true
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("Profile Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if selectedImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImageData = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    // Compress to reasonable size
                    if let uiImage = UIImage(data: data),
                       let compressed = uiImage.jpegData(compressionQuality: 0.7) {
                        selectedImageData = compressed
                    } else {
                        selectedImageData = data
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(imageData: $selectedImageData)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Camera View (UIKit wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage,
               let data = edited.jpegData(compressionQuality: 0.7) {
                parent.imageData = data
            } else if let original = info[.originalImage] as? UIImage,
                      let data = original.jpegData(compressionQuality: 0.7) {
                parent.imageData = data
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Local persistence for profile photo

class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()
    private let key = "ForkBookProfilePhoto"

    func save(_ data: Data?) {
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func load() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AvatarView(name: "Shreyas Nangalia", size: 88)
        AvatarView(name: "Arjun Mehta", size: 56)
        AvatarView(name: "Neha K", size: 40)
        RingedAvatarView(name: "Shreyas Nangalia", size: 88)
    }
    .padding()
    .background(Color.fbBg)
    .preferredColorScheme(.dark)
}
