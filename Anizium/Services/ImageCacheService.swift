import SwiftUI
import ImageIO

public final class ImageCacheService {
    public static let shared = ImageCacheService()
    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        cache.totalCostLimit = 250 * 1024 * 1024 // 250 MB RAM cache
        cache.countLimit = 600

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 250 * 1024 * 1024,
            diskCapacity: 800 * 1024 * 1024,
            diskPath: "anizium_disk_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 24
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 35
        self.session = URLSession(configuration: config)
    }

    public func getFromMemory(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    public func loadImage(from url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        let nsURL = url as NSURL
        if let cached = cache.object(forKey: nsURL) {
            return cached
        }

        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await session.data(for: req)

            guard let downsampled = downsample(data: data, to: targetSize ?? CGSize(width: 280, height: 420)) else {
                guard let raw = UIImage(data: data) else { return nil }
                cache.setObject(raw, forKey: nsURL, cost: data.count)
                return raw
            }

            cache.setObject(downsampled, forKey: nsURL, cost: data.count)
            return downsampled
        } catch {
            return nil
        }
    }

    public func prefetchImages(_ urls: [URL], targetSize: CGSize? = nil) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(30) {
                    group.addTask {
                        _ = await self.loadImage(from: url, targetSize: targetSize)
                    }
                }
            }
        }
    }

    public func clear() {
        cache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }

    private func downsample(data: Data, to pointSize: CGSize, scale: CGFloat = 2.0) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return UIImage(cgImage: downsampledImage)
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let targetSize: CGSize?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    public init(
        url: URL?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder
        if let u = url, let cached = ImageCacheService.shared.getFromMemory(for: u) {
            self._image = State(initialValue: cached)
        }
    }

    public var body: some View {
        Group {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .task(id: url) {
                        guard let url = url else { return }
                        if let cached = ImageCacheService.shared.getFromMemory(for: url) {
                            self.image = cached
                            return
                        }
                        let loaded = await ImageCacheService.shared.loadImage(from: url, targetSize: targetSize)
                        if !Task.isCancelled {
                            self.image = loaded
                        }
                    }
            }
        }
    }
}
