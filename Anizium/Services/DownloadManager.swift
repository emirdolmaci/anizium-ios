import SwiftUI
import Combine

public struct DownloadItem: Identifiable, Codable, Equatable {
    public let id: String
    public let animeId: String
    public let animeTitle: String
    public let episodeNumber: String
    public let episodeTitle: String
    public let posterURL: String?
    public let fileName: String
    public var progress: Double
    public var isCompleted: Bool
    public var fileSizeString: String

    public var localURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent("Downloads").appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
}

public final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = DownloadManager()

    @Published public var downloads: [DownloadItem] = []
    @Published public var activeDownloadId: String?

    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var metadataURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("downloads_meta.json")
    }

    private var downloadsFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("Downloads")
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        loadSavedMetadata()
    }

    public func isDownloaded(id: String) -> Bool {
        return downloads.first(where: { $0.id == id && $0.isCompleted })?.localURL != nil
    }

    public func isDownloading(id: String) -> Bool {
        return tasks[id] != nil
    }

    public func localURL(for id: String) -> URL? {
        return downloads.first(where: { $0.id == id && $0.isCompleted })?.localURL
    }

    public func downloadEpisode(
        animeId: String,
        animeTitle: String,
        episode: Episode,
        seasonNumber: Int,
        posterURL: String? = nil
    ) async throws {
        let res = try await AniziumAPI.shared.fetchSource(
            id: animeId,
            season: seasonNumber,
            episode: episode.episodeNumber
        )
        guard let groups = res.groups, !groups.isEmpty else {
            throw NSError(domain: "DownloadManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video kaynağı bulunamadı."])
        }
        let group = groups.first(where: { $0.group == "trdub" })
            ?? groups.first(where: { $0.group == "original" })
            ?? groups.first!
        let stream = group.items?.first(where: { $0.qualityInt == 1080 })
            ?? group.items?.first(where: { $0.qualityInt == 720 })
            ?? group.items?.first
        guard let link = stream?.link, let videoURL = URL(string: link) else {
            throw NSError(domain: "DownloadManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "İndirilebilir video bağlantısı bulunamadı."])
        }
        await MainActor.run {
            self.startDownload(
                animeId: animeId,
                animeTitle: animeTitle,
                episode: episode,
                videoURL: videoURL,
                posterURL: posterURL
            )
        }
    }

    public func startDownload(
        animeId: String,
        animeTitle: String,
        episode: Episode,
        videoURL: URL,
        posterURL: String? = nil
    ) {
        let epId = episode.id
        guard !isDownloaded(id: epId), tasks[epId] == nil else { return }

        let ext = videoURL.pathExtension.isEmpty ? "mp4" : videoURL.pathExtension
        let fileName = "\(animeId)_\(epId).\(ext)"

        let item = DownloadItem(
            id: epId,
            animeId: animeId,
            animeTitle: animeTitle,
            episodeNumber: "\(episode.episodeNumber)",
            episodeTitle: episode.name ?? "\(episode.episodeNumber). Bölüm",
            posterURL: posterURL,
            fileName: fileName,
            progress: 0.0,
            isCompleted: false,
            fileSizeString: "İndiriliyor..."
        )

        downloads.removeAll { $0.id == epId }
        downloads.insert(item, at: 0)
        saveMetadata()

        var request = URLRequest(url: videoURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        task.taskDescription = epId
        tasks[epId] = task
        activeDownloadId = epId
        task.resume()
    }

    public func deleteDownload(id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)

        if let index = downloads.firstIndex(where: { $0.id == id }) {
            let item = downloads[index]
            if let url = item.localURL {
                try? FileManager.default.removeItem(at: url)
            }
            downloads.remove(at: index)
            saveMetadata()
        }
    }

    // MARK: - URLSessionDownloadDelegate
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let epId = downloadTask.taskDescription,
              totalBytesExpectedToWrite > 0 else { return }

        let prog = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let mb = Double(totalBytesWritten) / (1024 * 1024)
        let totalMb = Double(totalBytesExpectedToWrite) / (1024 * 1024)

        if let idx = downloads.firstIndex(where: { $0.id == epId }) {
            downloads[idx].progress = prog
            downloads[idx].fileSizeString = String(format: "%.1f / %.1f MB", mb, totalMb)
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let epId = downloadTask.taskDescription,
              let idx = downloads.firstIndex(where: { $0.id == epId }) else { return }

        let item = downloads[idx]
        let destURL = downloadsFolder.appendingPathComponent(item.fileName)

        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            let attr = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let size = attr[.size] as? Int64 ?? 0
            let mb = Double(size) / (1024 * 1024)

            downloads[idx].progress = 1.0
            downloads[idx].isCompleted = true
            downloads[idx].fileSizeString = String(format: "%.1f MB", mb)
            tasks.removeValue(forKey: epId)
            saveMetadata()
        } catch {
            tasks.removeValue(forKey: epId)
            downloads[idx].fileSizeString = "Hata oluştu"
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let epId = task.taskDescription else { return }
        tasks.removeValue(forKey: epId)
        if error != nil, let idx = downloads.firstIndex(where: { $0.id == epId }) {
            downloads[idx].fileSizeString = "İndirme başarısız"
        }
    }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(downloads) {
            try? data.write(to: metadataURL)
        }
    }

    private func loadSavedMetadata() {
        if let data = try? Data(contentsOf: metadataURL),
           let list = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            self.downloads = list.filter { $0.localURL != nil }
        }
    }
}
