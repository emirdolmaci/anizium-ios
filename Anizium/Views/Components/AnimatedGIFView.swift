import SwiftUI
import UIKit
import ImageIO

public final class GIFImageCache {
    public static let shared = GIFImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    public func get(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    public func set(_ image: UIImage, for url: URL, cost: Int = 0) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    public func loadAnimatedImage(from url: URL) async -> UIImage? {
        if let cached = get(for: url) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = decodeAnimatedImage(from: data) else { return nil }
            set(image, for: url, cost: data.count)
            return image
        } catch {
            return nil
        }
    }

    private func decodeAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            return UIImage(data: data)
        }

        var images: [UIImage] = []
        var totalDuration: Double = 0.0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            var frameDuration: Double = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                // GIF properties
                if let gifProps = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    } else if let delay = gifProps[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    }
                }
                // WebP properties (if animated WebP)
                #if canImport(UniformTypeIdentifiers)
                if let webpProps = properties[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
                    if let delay = webpProps[kCGImagePropertyWebPUnclampedDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    } else if let delay = webpProps[kCGImagePropertyWebPDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    }
                }
                #endif
            }
            totalDuration += frameDuration
        }

        let finalDuration = totalDuration > 0.0 ? totalDuration : Double(count) * 0.1
        return UIImage.animatedImage(with: images, duration: finalDuration)
    }
}

public struct AnimatedGIFView: UIViewRepresentable {
    public let url: URL?
    public let contentMode: UIView.ContentMode

    public init(url: URL?, contentMode: UIView.ContentMode = .scaleAspectFill) {
        self.url = url
        self.contentMode = contentMode
    }

    public func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    public func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let url = url else {
            uiView.image = nil
            return
        }

        if let cached = GIFImageCache.shared.get(for: url) {
            uiView.image = cached
            uiView.startAnimating()
            return
        }

        Task {
            if let image = await GIFImageCache.shared.loadAnimatedImage(from: url) {
                await MainActor.run {
                    uiView.image = image
                    uiView.startAnimating()
                }
            }
        }
    }
}
