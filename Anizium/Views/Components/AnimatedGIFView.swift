import SwiftUI
import UIKit
import ImageIO

public final class DecodedAnimation: NSObject {
    public let frames: [UIImage]
    public let duration: TimeInterval
    public let isAnimated: Bool

    public init(frames: [UIImage], duration: TimeInterval, isAnimated: Bool) {
        self.frames = frames
        self.duration = duration
        self.isAnimated = isAnimated
    }
}

public final class GIFImageCache {
    public static let shared = GIFImageCache()
    private let cache = NSCache<NSURL, DecodedAnimation>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    public func get(for url: URL) -> DecodedAnimation? {
        return cache.object(forKey: url as NSURL)
    }

    public func set(_ anim: DecodedAnimation, for url: URL, cost: Int = 0) {
        cache.setObject(anim, forKey: url as NSURL, cost: cost)
    }

    public func loadAnimatedImage(from url: URL) async -> DecodedAnimation? {
        if let cached = get(for: url) {
            return cached
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let anim = decodeData(data) else { return nil }
            set(anim, for: url, cost: data.count)
            return anim
        } catch {
            return nil
        }
    }

    private func decodeData(_ data: Data) -> DecodedAnimation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            if let img = UIImage(data: data) {
                return DecodedAnimation(frames: [img], duration: 0, isAnimated: false)
            }
            return nil
        }

        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            if let img = UIImage(data: data) {
                return DecodedAnimation(frames: [img], duration: 0, isAnimated: false)
            }
            return nil
        }

        var images: [UIImage] = []
        var totalDuration: Double = 0.0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            var frameDuration: Double = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                if let gifProps = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double, delay > 0.01 {
                        frameDuration = delay
                    } else if let delay = gifProps[kCGImagePropertyGIFDelayTime] as? Double, delay > 0.01 {
                        frameDuration = delay
                    }
                }
                #if canImport(UniformTypeIdentifiers)
                if let webpProps = properties[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
                    if let delay = webpProps[kCGImagePropertyWebPUnclampedDelayTime] as? Double, delay > 0.01 {
                        frameDuration = delay
                    } else if let delay = webpProps[kCGImagePropertyWebPDelayTime] as? Double, delay > 0.01 {
                        frameDuration = delay
                    }
                }
                #endif
            }
            totalDuration += frameDuration
        }

        let finalDuration = totalDuration > 0.0 ? totalDuration : Double(images.count) * 0.1
        return DecodedAnimation(frames: images, duration: finalDuration, isAnimated: images.count > 1)
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
            uiView.stopAnimating()
            uiView.animationImages = nil
            uiView.image = nil
            return
        }

        if let cached = GIFImageCache.shared.get(for: url) {
            apply(cached, to: uiView)
            return
        }

        Task {
            if let anim = await GIFImageCache.shared.loadAnimatedImage(from: url) {
                await MainActor.run {
                    apply(anim, to: uiView)
                }
            }
        }
    }

    private func apply(_ anim: DecodedAnimation, to imageView: UIImageView) {
        if anim.isAnimated && anim.frames.count > 1 {
            imageView.image = anim.frames.first
            imageView.animationImages = anim.frames
            imageView.animationDuration = anim.duration
            imageView.animationRepeatCount = 0
            imageView.startAnimating()
        } else {
            imageView.stopAnimating()
            imageView.animationImages = nil
            imageView.image = anim.frames.first
        }
    }
}
