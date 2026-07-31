import Foundation
import Observation
import SwiftData
import UIKit

// MARK: - Errors

enum ScanError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key found. Add one in Settings before scanning."
        }
    }
}

// MARK: - Coordinator

/// Drives the scan pipeline: image → OCR → LLM parse → SwiftData save.
@Observable
final class ScanCoordinator {

    enum Stage: Equatable {
        case idle
        case scanning
        case parsing
        case saving
        case done
    }

    private let vision: VisionOCRManager
    private let parser: DNDParserService

    var stage: Stage = .idle
    var errorMessage: String?

    init(vision: VisionOCRManager = VisionOCRManager(), parser: DNDParserService = DNDParserService()) {
        self.vision = vision
        self.parser = parser
    }

    var isProcessing: Bool {
        stage != .idle
    }

    var stageLabel: String {
        switch stage {
        case .idle: return ""
        case .scanning: return "Scanning Handwriting..."
        case .parsing: return "Structuring Quests & Loot..."
        case .saving: return "Saving..."
        case .done: return "Done!"
        }
    }

    /// Runs the full pipeline. Call from the main actor.
    @MainActor
    func process(image: UIImage, context: ModelContext) async {
        errorMessage = nil

        do {
            guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
                throw ScanError.missingAPIKey
            }

            stage = .scanning
            let rawText = try await vision.extractText(from: image)

            stage = .parsing
            let parsed = try await parser.parse(rawText: rawText, apiKey: apiKey)

            stage = .saving
            try parser.persist(parsed, rawText: rawText, into: context)

            stage = .done
            try? await Task.sleep(for: .seconds(1.2))
            stage = .idle
        } catch is CancellationError {
            stage = .idle
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            stage = .idle
        }
    }
}
