import SwiftUI
import AVKit
import AVFoundation
import CoreMedia
import Combine

public struct PlayerView: View {
    public let animeId: String
    public let seasonNumber: Int
    public let episode: Episode
    public let animeTitle: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = AniziumAPI.shared

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var sourceResponse: SourceResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var availableStreams: [StreamItem] = []
    @State private var selectedStream: StreamItem?

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?

    // Skip Intro & Next Episode state
    @State private var showSkipIntro = false
    @State private var introEndTime: Double = 0
    @State private var showNextEpisode = false

    // Subtitle state
    @State private var subtitles: [SubtitleCue] = []
    @State private var currentSubtitleText: String = ""
    @State private var selectedSubtitle: SubtitleItem?

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.red)
                        .scaleEffect(1.2)
                    Text("Video kaynağı hazırlanıyor...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(6)
                }
            } else if let player = player {
                // Video Surface
                CustomVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showControls.toggle()
                            if showControls { resetControlsTimer() }
                        }
                    }

                // Subtitle Display Overlay
                if !currentSubtitleText.isEmpty {
                    VStack {
                        Spacer()
                        Text(currentSubtitleText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(6)
                            .padding(.bottom, showControls ? 90 : 30)
                            .shadow(radius: 2)
                    }
                    .allowsHitTesting(false)
                }

                // Skip Intro Button
                if showSkipIntro {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: skipIntro) {
                                HStack(spacing: 6) {
                                    Image(systemName: "forward.end.fill")
                                    Text("İntroyu Atla")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, showControls ? 100 : 40)
                        }
                    }
                }

                // Next Episode Button
                if showNextEpisode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: playNextEpisode) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.circle.fill")
                                    Text("Sonraki Bölüm")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, showControls ? 100 : 40)
                        }
                    }
                }

                // Player Controls Overlay
                if showControls {
                    PlayerControlsOverlay(
                        title: "\(animeTitle) - \(episode.number). Bölüm",
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: duration,
                        availableStreams: availableStreams,
                        selectedStream: selectedStream,
                        subtitles: sourceResponse?.subtitles ?? [],
                        selectedSubtitle: selectedSubtitle,
                        onPlayPause: togglePlayPause,
                        onSeek: seekTo,
                        onSelectStream: switchQuality,
                        onSelectSubtitle: switchSubtitle,
                        onClose: { dismiss() }
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            loadSource()
        }
        .onDisappear {
            cleanUpPlayer()
        }
    }

    // MARK: - Player Actions
    private func loadSource() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let res = try await api.fetchSource(
                    id: animeId,
                    season: seasonNumber,
                    episode: episode.number
                )
                await MainActor.run {
                    self.sourceResponse = res
                    setupPlayback(with: res)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Video yüklenemedi: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func setupPlayback(with res: SourceResponse) {
        guard let group = res.groups?.first, let items = group.items, !items.isEmpty else {
            self.errorMessage = "Oynatılabilir video akışı bulunamadı."
            self.isLoading = false
            return
        }

        self.availableStreams = items.sorted { $0.quality > $1.quality }
        // Default to 1080p or best available
        let best = items.first(where: { $0.quality == 1080 }) ?? items.first!
        self.selectedStream = best

        if let firstSub = res.subtitles?.first {
            self.selectedSubtitle = firstSub
            loadSubtitles(from: firstSub.link)
        }

        initAVPlayer(urlStr: best.link)
    }

    private func initAVPlayer(urlStr: String, startAt: Double = 0) {
        guard let url = URL(string: urlStr) else { return }
        let playerItem = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: playerItem)
        self.player = p
        self.isLoading = false

        if startAt > 0 {
            p.seek(to: CMTime(seconds: startAt, preferredTimescale: 600))
        }

        p.play()
        self.isPlaying = true
        resetControlsTimer()

        // Time Observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let sec = time.seconds
            self.currentTime = sec

            if let item = p.currentItem, item.duration.isValid && !item.duration.isIndefinite {
                self.duration = item.duration.seconds
            }

            self.checkIntroAndOutro(currentTime: sec)
            self.updateSubtitle(currentTime: sec)
        }
    }

    private func switchQuality(to stream: StreamItem) {
        guard stream.link != selectedStream?.link else { return }
        let currentPos = currentTime
        selectedStream = stream
        cleanUpPlayer()
        initAVPlayer(urlStr: stream.link, startAt: currentPos)
    }

    private func switchSubtitle(to sub: SubtitleItem?) {
        self.selectedSubtitle = sub
        if let sub = sub {
            loadSubtitles(from: sub.link)
        } else {
            self.subtitles = []
            self.currentSubtitleText = ""
        }
    }

    private func checkIntroAndOutro(currentTime: Double) {
        guard let content = sourceResponse?.content else { return }

        // Skip intro check
        if let opening = content.opening,
           let startStr = opening.start, let endStr = opening.end,
           let startSec = parseTimeString(startStr), let endSec = parseTimeString(endStr) {
            self.introEndTime = endSec
            self.showSkipIntro = (currentTime >= startSec && currentTime <= endSec)
        } else {
            self.showSkipIntro = false
        }

        // Next episode check
        if let nextStr = content.next_episode, let nextSec = parseTimeString(nextStr) {
            self.showNextEpisode = (currentTime >= nextSec)
        } else {
            self.showNextEpisode = false
        }
    }

    private func skipIntro() {
        if introEndTime > 0 {
            seekTo(introEndTime)
            showSkipIntro = false
        }
    }

    private func playNextEpisode() {
        // Dismiss current and trigger next episode if applicable
        dismiss()
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
            resetControlsTimer()
        }
    }

    private func seekTo(_ seconds: Double) {
        guard let p = player else { return }
        p.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation {
                if self.isPlaying {
                    self.showControls = false
                }
            }
        }
    }

    private func cleanUpPlayer() {
        controlsTimer?.invalidate()
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }

    // MARK: - Subtitles (WebVTT)
    private func loadSubtitles(from urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let str = String(data: data, encoding: .utf8) {
                    let parsed = parseWebVTT(str)
                    await MainActor.run {
                        self.subtitles = parsed
                    }
                }
            } catch {
                print("Subtitle load error: \(error)")
            }
        }
    }

    private func updateSubtitle(currentTime: Double) {
        if let match = subtitles.first(where: { currentTime >= $0.start && currentTime <= $0.end }) {
            self.currentSubtitleText = match.text
        } else {
            self.currentSubtitleText = ""
        }
    }

    private func parseTimeString(_ s: String) -> Double? {
        let parts = s.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        } else if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return nil
    }

    private func parseWebVTT(_ text: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count == 2,
                   let start = parseVttTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
                   let end = parseVttTimestamp(parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? "") {
                    i += 1
                    var cueText = ""
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        cueText += (cueText.isEmpty ? "" : "\n") + lines[i]
                        i += 1
                    }
                    cues.append(SubtitleCue(start: start, end: end, text: cueText))
                }
            }
            i += 1
        }
        return cues
    }

    private func parseVttTimestamp(_ s: String) -> Double? {
        let clean = s.replacingOccurrences(of: ",", with: ".")
        let parts = clean.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        } else if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return nil
    }
}

public struct SubtitleCue {
    public let start: Double
    public let end: Double
    public let text: String
}

// Custom Player Layer to avoid default AVPlayerViewController controls
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// Overlay Controls
struct PlayerControlsOverlay: View {
    let title: String
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    let duration: Double
    let availableStreams: [StreamItem]
    let selectedStream: StreamItem?
    let subtitles: [SubtitleItem]
    let selectedSubtitle: SubtitleItem?

    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onSelectStream: (StreamItem) -> Void
    let onSelectSubtitle: (SubtitleItem?) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack {
                // Top Header
                HStack(spacing: 16) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                    }

                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Quality Menu
                    Menu {
                        ForEach(availableStreams) { stream in
                            Button(action: { onSelectStream(stream) }) {
                                HStack {
                                    Text("\(stream.quality)p")
                                    if stream.id == selectedStream?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("\(selectedStream?.quality ?? 1080)p")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }

                    // Subtitle Menu
                    Menu {
                        Button("Kapalı") { onSelectSubtitle(nil) }
                        ForEach(subtitles) { sub in
                            Button(action: { onSelectSubtitle(sub) }) {
                                HStack {
                                    Text(sub.name ?? "Altyazı")
                                    if sub.id == selectedSubtitle?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                // Center Play / Pause & 10s Skip
                HStack(spacing: 40) {
                    Button(action: { onSeek(max(0, currentTime - 10)) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }

                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                    }

                    Button(action: { onSeek(min(duration, currentTime + 10)) }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Bottom Timeline & Duration
                VStack(spacing: 4) {
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(formatTime(duration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Slider(value: $currentTime, in: 0...max(1, duration), onEditingChanged: { editing in
                        if !editing {
                            onSeek(currentTime)
                        }
                    })
                    .tint(.red)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func formatTime(_ sec: Double) -> String {
        let total = Int(sec)
        let m = (total / 60) % 60
        let s = total % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
