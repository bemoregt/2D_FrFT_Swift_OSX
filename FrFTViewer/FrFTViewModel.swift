import AppKit
import Foundation

@MainActor
final class FrFTViewModel: ObservableObject {
    @Published var alpha: Double = 1.0 {
        didSet {
            scheduleRender()
        }
    }

    @Published private(set) var originalImage: NSImage?
    @Published private(set) var transformedImage: NSImage?
    @Published private(set) var status: String = "Drop an image file into the window."
    @Published private(set) var isRendering = false

    private var sourceImage: GrayscaleImage?
    private var loadTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?

    var originalSubtitle: String {
        guard let originalImage else { return "Waiting for input" }
        return "\(Int(originalImage.size.width)) × \(Int(originalImage.size.height)) px"
    }

    var frftSubtitle: String {
        "alpha \(formatted(alpha))"
    }

    var transformedEmptyMessage: String {
        isRendering ? "Rendering..." : "Drop an image to compute the FrFT"
    }

    func loadImage(from url: URL) {
        loadTask?.cancel()
        renderTask?.cancel()

        status = "Loading \(url.lastPathComponent)..."
        isRendering = true

        guard let image = NSImage(contentsOf: url) else {
            status = "Could not read \(url.lastPathComponent)."
            isRendering = false
            return
        }

        originalImage = image
        transformedImage = nil

        loadTask = Task.detached(priority: .userInitiated) { [weak self, image] in
            guard let grayscale = FrFTProcessor.makeGrayscaleImage(from: image, maxDimension: 128) else {
                await MainActor.run {
                    self?.status = "Unable to decode the dropped image."
                    self?.isRendering = false
                }
                return
            }

            await MainActor.run {
                guard let self else { return }
                self.sourceImage = grayscale
                self.status = "Loaded \(url.lastPathComponent)"
                self.scheduleRender()
            }
        }
    }

    private func scheduleRender() {
        renderTask?.cancel()

        guard let sourceImage else {
            transformedImage = nil
            isRendering = false
            status = "Drop an image file into the window."
            return
        }

        let currentAlpha = alpha
        isRendering = true
        status = "Rendering alpha \(formatted(currentAlpha))..."

        renderTask = Task.detached(priority: .userInitiated) { [weak self, sourceImage, currentAlpha] in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }

            let rendered = FrFTProcessor.render(from: sourceImage, alpha: currentAlpha) {
                Task.isCancelled
            }

            guard let rendered else { return }

            await MainActor.run {
                guard let self else { return }
                self.transformedImage = rendered
                self.isRendering = false
                self.status = "Rendered alpha \(self.formatted(currentAlpha))."
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
