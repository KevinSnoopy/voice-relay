import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum ThumbnailProvider {
    static let targetSize = CGSize(width: 320, height: 200)

    /// Captures a window thumbnail. macOS 14+ uses SCScreenshotManager; macOS 13
    /// falls back to the deprecated CGWindowListCreateImage, kept isolated here.
    static func jpeg(for window: SCWindow) async -> Data? {
        if #available(macOS 14.0, *) {
            if let image = try? await screenshot(window: window) {
                return encodeJPEG(resize(image, to: targetSize), quality: 0.62)
            }
        }
        guard let image = legacyScreenshot(windowID: window.windowID) else { return nil }
        return encodeJPEG(resize(image, to: targetSize), quality: 0.62)
    }

    @available(macOS 14.0, *)
    private static func screenshot(window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(targetSize.width)
        config.height = Int(targetSize.height)
        config.showsCursor = false
        config.capturesAudio = false
        config.scalesToFit = true
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private static func legacyScreenshot(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    private static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else { return nil }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high

        let scale = min(CGFloat(width) / CGFloat(image.width), CGFloat(height) / CGFloat(image.height))
        let drawWidth = CGFloat(image.width) * scale
        let drawHeight = CGFloat(image.height) * scale
        let rect = CGRect(
            x: (CGFloat(width) - drawWidth) / 2,
            y: (CGFloat(height) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        context.draw(image, in: rect)
        return context.makeImage()
    }

    private static func encodeJPEG(_ image: CGImage?, quality: CGFloat) -> Data? {
        guard let image else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
