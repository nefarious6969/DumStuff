import AVFoundation
import CoreImage
import CoreVideo
import Combine

/// Samples a playing video locally so the same Core ML detector can protect
/// frames that were not marked sensitive by the source provider.
@MainActor
final class VideoSafetyMonitor: ObservableObject {
    @Published private(set) var regions: [SensitiveRegion] = []

    private let scanner: SensitiveMediaScanning
    private let context = CIContext()
    private var output: AVPlayerItemVideoOutput?
    private weak var attachedItem: AVPlayerItem?
    private var timer: Timer?

    init(scanner: SensitiveMediaScanning = VisionSafetyScanner()) {
        self.scanner = scanner
    }

    func attach(to item: AVPlayerItem) {
        stop()
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        item.add(videoOutput)
        output = videoOutput
        attachedItem = item
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.sampleCurrentFrame()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let output, let attachedItem { attachedItem.remove(output) }
        output = nil
        attachedItem = nil
        regions = []
    }

    private func sampleCurrentFrame() {
        guard let output else { return }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else { return }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task {
            let found = (try? await scanner.scan(image: image)) ?? []
            regions = found
        }
    }
}
