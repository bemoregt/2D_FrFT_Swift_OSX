import AppKit
import CoreGraphics
import Foundation

struct GrayscaleImage {
    let width: Int
    let height: Int
    let pixels: [Double]
}

private struct Complex {
    var real: Double
    var imag: Double

    static let zero = Complex(real: 0, imag: 0)

    var magnitude: Double {
        hypot(real, imag)
    }

    static func + (lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real + rhs.real, imag: lhs.imag + rhs.imag)
    }

    static func += (lhs: inout Complex, rhs: Complex) {
        lhs.real += rhs.real
        lhs.imag += rhs.imag
    }

    static func * (lhs: Complex, rhs: Complex) -> Complex {
        Complex(
            real: lhs.real * rhs.real - lhs.imag * rhs.imag,
            imag: lhs.real * rhs.imag + lhs.imag * rhs.real
        )
    }

    static func * (lhs: Complex, rhs: Double) -> Complex {
        Complex(real: lhs.real * rhs, imag: lhs.imag * rhs)
    }
}

enum FrFTProcessor {
    static func makeGrayscaleImage(from image: NSImage, maxDimension: Int = 128) -> GrayscaleImage? {
        guard let cgImage = cgImage(from: image) else { return nil }
        return makeGrayscaleImage(from: cgImage, maxDimension: maxDimension)
    }

    static func render(from source: GrayscaleImage, alpha: Double, isCancelled: () -> Bool) -> NSImage? {
        guard !isCancelled() else { return nil }

        let transformed = transform2D(source, alpha: alpha, isCancelled: isCancelled)
        guard !isCancelled(), let transformed else { return nil }

        let magnitudes = transformed.values.map { log1p($0.magnitude) }
        let maxMagnitude = magnitudes.max() ?? 1
        let normalized = magnitudes.map { value -> UInt8 in
            let scaled = maxMagnitude > 0 ? min(1, value / maxMagnitude) : 0
            return UInt8((scaled * 255).rounded())
        }

        guard let cgImage = cgImage(from: normalized, width: transformed.width, height: transformed.height) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: transformed.width, height: transformed.height))
    }

    private static func makeGrayscaleImage(from cgImage: CGImage, maxDimension: Int) -> GrayscaleImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let scale = min(1, Double(maxDimension) / Double(max(width, height)))
        let targetWidth = max(1, Int((Double(width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))
        let bytesPerRow = targetWidth
        var pixels = [UInt8](repeating: 0, count: targetWidth * targetHeight)

        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        let normalized = pixels.map { Double($0) / 255.0 }
        return GrayscaleImage(width: targetWidth, height: targetHeight, pixels: normalized)
    }

    private static func transform2D(_ image: GrayscaleImage, alpha: Double, isCancelled: () -> Bool) -> ComplexImage? {
        guard !isCancelled() else { return nil }
        guard let rowTransformed = transformRows(image, alpha: alpha, isCancelled: isCancelled) else { return nil }
        guard !isCancelled() else { return nil }
        return transformColumns(rowTransformed, alpha: alpha, isCancelled: isCancelled)
    }

    private static func transformRows(_ image: GrayscaleImage, alpha: Double, isCancelled: () -> Bool) -> ComplexImage? {
        var output = Array(repeating: Complex.zero, count: image.width * image.height)

        for y in 0..<image.height {
            if isCancelled() { return nil }

            let start = y * image.width
            let row = image.pixels[start..<(start + image.width)].map { Complex(real: $0, imag: 0) }
            let transformed = transform1D(row, alpha: alpha, isCancelled: isCancelled)

            guard let transformed else { return nil }

            for x in 0..<image.width {
                output[start + x] = transformed[x]
            }
        }

        return ComplexImage(width: image.width, height: image.height, values: output)
    }

    private static func transformColumns(_ image: ComplexImage, alpha: Double, isCancelled: () -> Bool) -> ComplexImage? {
        var output = Array(repeating: Complex.zero, count: image.width * image.height)

        for x in 0..<image.width {
            if isCancelled() { return nil }

            var column = [Complex]()
            column.reserveCapacity(image.height)
            for y in 0..<image.height {
                column.append(image.values[y * image.width + x])
            }

            guard let transformed = transform1D(column, alpha: alpha, isCancelled: isCancelled) else {
                return nil
            }

            for y in 0..<image.height {
                output[y * image.width + x] = transformed[y]
            }
        }

        return ComplexImage(width: image.width, height: image.height, values: output)
    }

    private static func transform1D(_ signal: [Complex], alpha: Double, isCancelled: () -> Bool) -> [Complex]? {
        let count = signal.count
        guard count > 0 else { return [] }

        let clampedAlpha = min(2.0, max(0.0, alpha))
        let epsilon = 0.01

        if clampedAlpha < epsilon {
            return signal
        }

        if abs(clampedAlpha - 2.0) < epsilon {
            return Array(signal.reversed())
        }

        if abs(clampedAlpha - 1.0) < epsilon {
            return dft(signal, isCancelled: isCancelled)
        }

        let phi = clampedAlpha * .pi / 2.0
        let sinPhi = sin(phi)
        let cosPhi = cos(phi)

        guard abs(sinPhi) > 0.0001 else {
            return dft(signal, isCancelled: isCancelled)
        }

        let cotPhi = cosPhi / sinPhi
        let cscPhi = 1.0 / sinPhi
        let scale = 1.0 / Double(count)
        let center = Double(count - 1) / 2.0
        var output = Array(repeating: Complex.zero, count: count)

        for u in 0..<count {
            if isCancelled() { return nil }

            let uPos = Double(u) - center
            var sum = Complex.zero

            for x in 0..<count {
                let xPos = Double(x) - center
                let phase = .pi * scale * (
                    xPos * xPos * cotPhi
                    - 2.0 * xPos * uPos * cscPhi
                    + uPos * uPos * cotPhi
                )
                let weight = Complex(real: cos(phase), imag: sin(phase))
                sum += signal[x] * weight
            }

            output[u] = sum
        }

        return output
    }

    private static func dft(_ signal: [Complex], isCancelled: () -> Bool) -> [Complex]? {
        let count = signal.count
        let center = Double(count - 1) / 2.0
        let scale = 1.0 / Double(count)
        var output = Array(repeating: Complex.zero, count: count)

        for k in 0..<count {
            if isCancelled() { return nil }

            let kPos = Double(k) - center
            var sum = Complex.zero

            for n in 0..<count {
                let nPos = Double(n) - center
                let phase = -2.0 * .pi * scale * nPos * kPos
                let weight = Complex(real: cos(phase), imag: sin(phase))
                sum += signal[n] * weight
            }

            output[k] = sum
        }

        return output
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cgImage
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.cgImage
    }

    private static func cgImage(from pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

private struct ComplexImage {
    let width: Int
    let height: Int
    let values: [Complex]
}

