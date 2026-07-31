import PhotosUI
import SwiftUI
import UIKit

// MARK: - Scanner

/// Offers camera capture (physical device) or a photo-library pick for a page scan.
struct CameraScannerView: View {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                scannerButton(title: "Take Photo", systemImage: "camera.fill") {
                    showCamera = true
                }
                scannerButton(title: "Choose from Library", systemImage: "photo.on.rectangle") {
                    showLibrary = true
                }
            }
            .padding()
            .navigationTitle("Scan Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .photosPicker(isPresented: $showLibrary, selection: $selectedItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    onImage(image)
                    dismiss()
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onImage(image)
                        dismiss()
                    }
                }
            }
        }
    }

    private func scannerButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera

/// `UIImagePickerController` wrapper for on-device camera capture.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
