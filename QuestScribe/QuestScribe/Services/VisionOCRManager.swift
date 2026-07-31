import UIKit
import Vision

// MARK: - Errors

enum VisionError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not read the captured image."
        case .noTextFound:
            return "No handwritten text could be detected. Try a clearer, higher-contrast photo."
        }
    }
}

// MARK: - OCR Manager

/// Wraps Apple's on-device Vision framework to extract raw text from an image.
struct VisionOCRManager {

    /// Extracts text from a `UIImage` using `.accurate` recognition and language correction.
    /// - Parameter image: The captured or picked page scan.
    /// - Returns: The recognized text, one line per newline.
    /// - Throws: `VisionError` or a `Vision` framework error.
    func extractText(from image: UIImage) async throws -> String {
        let normalized = Self.normalizedImage(image)
        guard let cgImage = normalized.cgImage else {
            throw VisionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: VisionError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Re-draws the image with orientation applied so Vision receives upright pixels.
    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
