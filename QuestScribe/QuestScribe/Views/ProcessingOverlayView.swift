import SwiftUI

// MARK: - Processing Overlay

/// Full-screen loading overlay showing the scan pipeline stage.
struct ProcessingOverlayView: View {
    let stage: ScanCoordinator.Stage

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if stage == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                Text(label)
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: stage)
    }

    private var label: String {
        switch stage {
        case .idle: return ""
        case .scanning: return "Scanning Handwriting..."
        case .parsing: return "Structuring Quests & Loot..."
        case .saving: return "Saving..."
        case .done: return "Done!"
        }
    }
}
