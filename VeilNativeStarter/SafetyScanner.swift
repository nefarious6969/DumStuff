import Foundation
import Vision
import CoreML
import ImageIO
import Combine

@MainActor
final class SafetySettings: ObservableObject {
    enum CoverStyle: String, CaseIterable, Identifiable { case blur, pixel, bar, custom; var id: String { rawValue } }
    @Published var isEnabled = true
    @Published var coverStyle: CoverStyle = .blur
    @Published var coverText = "Covered"
    @Published var customImageData: Data?
}

protocol SensitiveMediaScanning {
    func scan(image: CGImage) async throws -> [SensitiveRegion]
}

/// The model is deliberately loaded by name so the app can ship with a reviewed model of its choice.
/// The model should return normalized bounding boxes and labels: breast, genitalia, or buttocks.
final class VisionSafetyScanner: SensitiveMediaScanning {
    private let request: VNCoreMLRequest?

    init(modelName: String = "SensitiveRegions") {
        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
           let model = try? MLModel(contentsOf: modelURL),
           let visionModel = try? VNCoreMLModel(for: model) {
            request = VNCoreMLRequest(model: visionModel)
        } else {
            request = nil
        }
    }

    func scan(image: CGImage) async throws -> [SensitiveRegion] {
        guard let request else { return [] }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return (request.results as? [VNRecognizedObjectObservation] ?? []).compactMap { observation in
            guard let label = observation.labels.first, label.confidence >= 0.60 else { return nil }
            let normalized = label.identifier.lowercased()
            guard ["breast", "genitalia", "buttocks"].contains(normalized) else { return nil }
            return SensitiveRegion(label: normalized, bounds: observation.boundingBox, confidence: label.confidence)
        }
    }
}

@MainActor
final class MediaSafetyViewModel: ObservableObject {
    @Published private(set) var regions: [SensitiveRegion] = []
    private let scanner: SensitiveMediaScanning

    init(scanner: SensitiveMediaScanning = VisionSafetyScanner()) {
        self.scanner = scanner
    }

    func scan(url: URL?) {
        guard let url else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
                let result = try await scanner.scan(image: image)
                regions = result
            } catch {
                regions = []
            }
        }
    }
}
