import SwiftUI
import AVKit
import AVFoundation
import CoreMedia
import Combine

public struct PlayerView: View {
    public let animeId: String
    public let seasonNumber: Int?
    public let episode: Episode?
    public let animeTitle: String
    public let isMovie: Bool
    public let startTime: Double

    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = AniziumAPI.shared

    // Subtitle Customization Preferences (Persisted across sessions)
    @AppStorage("sub_font_size") private var subFontSize: Double = 18.0
    @AppStorage("sub_color_hex") private var subColorHex: String = "FFD700"
    @AppStorage("sub_bg_mode") private var subBgMode: String = "semi_black" // "semi_black", "solid_black", "shadow_only"
    @AppStorage("sub_bottom_offset") private var subBottomOffset: Double = 0.0

    @State private var showSubtitleSettings = false

    public init(
        animeId: String,
        seasonNumber: Int? = nil,
        episode: Episode? = nil,
        animeTitle: String,
        isMovie: Bool = false,
        startTime: Double = 0
    ) {
        self.animeId = animeId
        self.seasonNumber = seasonNumber
        self.episode = episode
        self.animeTitle = animeTitle
        self.isMovie = isMovie
        self.startTime = startTime
    }

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var sourceResponse: SourceResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Audio Dub Groups & Streams
    @State private var availableGroups: [SourceGroup] = []
    @State private var selectedGroup: SourceGroup?
    @State private var availableStreams: [StreamItem] = []
    @State private var selectedStream: StreamItem?

    // Playback Speed
    @State private var playbackRate: Float = 1.0

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var lastSavedSecond: Int = 0

    // Skip Intro & Next Episode state
    @State private var showSkipIntro = false
    @State private var introEndTime: Double = 0
    @State private var showNextEpisode = false

    // Subtitle state
    @State private var subtitles: [SubtitleCue] = []
    @State private var currentSubtitleText: String = ""
    @State private var selectedSubtitle: SubtitleItem?

    private var subtitleBgColor: Color {
        switch subBgMode {
        case "solid_black": return Color.black
        case "shadow_only": return Color.clear
        default: return Color.black.opacity(0.75)
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.red)
                        .scaleEffect(1.2)
                    Text("Video ve ses kaynakları hazırlanıyor...")
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
                        .padding(.horizontal, 24)
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

                // Subtitle Display Overlay (Fully Customizable)
                if !currentSubtitleText.isEmpty {
                    VStack {
                        Spacer()
                        Text(currentSubtitleText)
                            .font(.system(size: CGFloat(subFontSize), weight: .bold))
                            .foregroundColor(Color(hex: subColorHex))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(subtitleBgColor)
                            .cornerRadius(6)
                            .shadow(color: .black, radius: subBgMode == "shadow_only" ? 5 : 2, x: 0, y: 1)
                            .padding(.bottom, (showControls ? 95 : 35) + CGFloat(subBottomOffset))
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
                        title: episode != nil ? "\(animeTitle) - \(episode!.episodeNumber). Bölüm" : animeTitle,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: duration,
                        availableGroups: availableGroups,
                        selectedGroup: selectedGroup,
                        availableStreams: availableStreams,
                        selectedStream: selectedStream,
                        playbackRate: playbackRate,
                        subtitles: sourceResponse?.subtitles ?? [],
                        selectedSubtitle: selectedSubtitle,
                        onPlayPause: togglePlayPause,
                        onSeek: seekTo,
                        onSelectGroup: switchAudioGroup,
                        onSelectStream: switchQuality,
                        onSelectSpeed: setPlaybackSpeed,
                        onSelectSubtitle: switchSubtitle,
                        onOpenSubtitleSettings: { showSubtitleSettings = true },
                        onClose: { dismiss() }
                    )
                    .transition(.opacity)
                }

                // Subtitle Appearance Customization Modal
                if showSubtitleSettings {
                    SubtitleSettingsModal(
                        fontSize: $subFontSize,
                        colorHex: $subColorHex,
                        bgMode: $subBgMode,
                        bottomOffset: $subBottomOffset,
                        onClose: { showSubtitleSettings = false }
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            loadSource()
        }
        .onDisappear {
            saveKeepWatchingProgress()
            cleanUpPlayer()
        }
    }

    // MARK: - Player Actions
    private func loadSource() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let res: SourceResponse
                if isMovie || episode == nil {
                    res = try await api.fetchMovieSource(id: animeId)
                } else {
                    res = try await api.fetchSource(
                        id: animeId,
                        season: seasonNumber ?? 1,
                        episode: episode?.episodeNumber ?? 1
                    )
                }
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
        guard let groups = res.groups, !groups.isEmpty else {
            self.errorMessage = "Oynatılabilir video akışı bulunamadı."
            self.isLoading = false
            return
        }

        self.availableGroups = groups

        // Pick preferred audio group: Turkish dub if available, otherwise original Japanese
        let defaultGroup = groups.first(where: { $0.group == "trdub" })
            ?? groups.first(where: { $0.group == "original" })
            ?? groups.first!

        self.selectedGroup = defaultGroup
        setupStreamsForGroup(defaultGroup, resumeAt: startTime)

        // Subtitles setup (default off for Turkish dub, on for Japanese)
        if defaultGroup.group != "trdub", let firstSub = res.subtitles?.first(where: { $0.group == "tr" }) ?? res.subtitles?.first {
            self.selectedSubtitle = firstSub
            loadSubtitles(from: firstSub.link)
        }
    }

    private func setupStreamsForGroup(_ group: SourceGroup, resumeAt: Double = 0) {
        guard let items = group.items, !items.isEmpty else { return }
        self.availableStreams = items.sorted { $0.qualityInt > $1.qualityInt }

        // Pick matching quality: 1080p, 720p or highest available
        let best = items.first(where: { $0.qualityInt == 1080 })
            ?? items.first(where: { $0.qualityInt == 720 })
            ?? items.first!
        self.selectedStream = best

        initAVPlayer(urlStr: best.link, startAt: resumeAt)
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

        p.rate = playbackRate
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

            // Periodic Keep-Watching Sync every 10 seconds
            let currentSecInt = Int(sec)
            if currentSecInt > 5 && currentSecInt != self.lastSavedSecond && currentSecInt % 10 == 0 {
                self.lastSavedSecond = currentSecInt
                self.saveKeepWatchingProgress()
            }
        }
    }

    private func switchAudioGroup(to group: SourceGroup) {
        guard group.id != selectedGroup?.id else { return }
        let currentPos = currentTime
        selectedGroup = group
        cleanUpPlayer()

        guard let items = group.items, !items.isEmpty else { return }
        availableStreams = items.sorted { $0.qualityInt > $1.qualityInt }

        // Retain same quality if available
        let targetQuality = selectedStream?.qualityInt ?? 1080
        let matching = items.first(where: { $0.qualityInt == targetQuality }) ?? items.first!
        selectedStream = matching

        initAVPlayer(urlStr: matching.link, startAt: currentPos)
    }

    private func switchQuality(to stream: StreamItem) {
        guard stream.link != selectedStream?.link else { return }
        let currentPos = currentTime
        selectedStream = stream
        cleanUpPlayer()
        initAVPlayer(urlStr: stream.link, startAt: currentPos)
    }

    private func setPlaybackSpeed(_ speed: Float) {
        self.playbackRate = speed
        if isPlaying {
            player?.rate = speed
        }
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

    private func saveKeepWatchingProgress() {
        guard currentTime > 5 else { return }
        let time = currentTime
        let id = animeId
        let season = seasonNumber
        let ep = episode?.episodeNumber
        Task {
            try? await api.saveKeepWatching(
                id: id,
                season: season,
                episode: ep,
                time: time
            )
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
        dismiss()
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.rate = playbackRate
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

// Custom Player Layer
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
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

    let availableGroups: [SourceGroup]
    let selectedGroup: SourceGroup?
    let availableStreams: [StreamItem]
    let selectedStream: StreamItem?
    let playbackRate: Float
    let subtitles: [SubtitleItem]
    let selectedSubtitle: SubtitleItem?

    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onSelectGroup: (SourceGroup) -> Void
    let onSelectStream: (StreamItem) -> Void
    let onSelectSpeed: (Float) -> Void
    let onSelectSubtitle: (SubtitleItem?) -> Void
    let onOpenSubtitleSettings: () -> Void
    let onClose: () -> Void

    private func qualityTitle(for stream: StreamItem) -> String {
        switch stream.qualityInt {
        case 2160: return "4K UHD"
        case 1440: return "2K QHD"
        case 1080: return "1080p FHD"
        case 720: return "720p HD"
        case 480: return "480p SD"
        default: return "\(stream.qualityInt)p"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack {
                // Top Header
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Audio Dub Selector Menu
                    if availableGroups.count > 1 {
                        Menu {
                            ForEach(availableGroups) { group in
                                Button(action: { onSelectGroup(group) }) {
                                    HStack {
                                        Text(group.name ?? group.group ?? "Ses")
                                        if group.id == selectedGroup?.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                Text(selectedGroup?.name ?? "Ses")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(5)
                        }
                    }

                    // Quality Menu (4K, 2K, 1080p, 720p, 480p)
                    Menu {
                        ForEach(availableStreams) { stream in
                            Button(action: { onSelectStream(stream) }) {
                                HStack {
                                    Text(qualityTitle(for: stream))
                                    if stream.id == selectedStream?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(selectedStream != nil ? qualityTitle(for: selectedStream!) : "1080p")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(5)
                    }

                    // Playback Speed Menu
                    Menu {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                            Button(action: { onSelectSpeed(Float(speed)) }) {
                                HStack {
                                    Text(String(format: "%.2fx", speed))
                                    if playbackRate == Float(speed) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(String(format: "%.1fx", playbackRate))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(5)
                    }

                    // Subtitle & Style Menu
                    Menu {
                        Section("ALTYAZI DİLİ") {
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
                        }

                        Section("GÖRÜNÜM AYARLARI") {
                            Button(action: onOpenSubtitleSettings) {
                                Label("Altyazı Görünümünü Özelleştir", systemImage: "textformat.size")
                            }
                        }
                    } label: {
                        Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                            .font(.system(size: 15))
                            .foregroundColor(selectedSubtitle != nil ? .yellow : .white)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                // Center Play / Pause & 10s Skip
                HStack(spacing: 44) {
                    Button(action: { onSeek(max(0, currentTime - 10)) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }

                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 58))
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
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text(formatTime(duration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
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

// Subtitle Appearance Customization Modal
struct SubtitleSettingsModal: View {
    @Binding var fontSize: Double
    @Binding var colorHex: String
    @Binding var bgMode: String
    @Binding var bottomOffset: Double
    let onClose: () -> Void

    private let colors = [
        ("Sarı", "FFD700"),
        ("Beyaz", "FFFFFF"),
        ("Cyan", "00E5FF"),
        ("Yeşil", "69F0AE")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Altyazı Görünümü")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Kapat") { onClose() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }

                // Live Preview Box
                VStack {
                    Text("Senin adın ne? (Örnek Altyazı)")
                        .font(.system(size: CGFloat(fontSize), weight: .bold))
                        .foregroundColor(Color(hex: colorHex))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(previewBgColor)
                        .cornerRadius(6)
                        .shadow(color: .black, radius: bgMode == "shadow_only" ? 5 : 2, x: 0, y: 1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color(hex: "121216"))
                .cornerRadius(10)

                // Font Size Control
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Yazı Boyutu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Picker("Boyut", selection: $fontSize) {
                        Text("Küçük (14)").tag(14.0)
                        Text("Normal (18)").tag(18.0)
                        Text("Büyük (22)").tag(22.0)
                        Text("Ekstra (26)").tag(26.0)
                    }
                    .pickerStyle(.segmented)
                }

                // Color Selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Yazı Rengi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(colors, id: \.1) { item in
                            Button(action: { colorHex = item.1 }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: item.1))
                                        .frame(width: 14, height: 14)
                                    Text(item.0)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(colorHex == item.1 ? .white : .white.opacity(0.6))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colorHex == item.1 ? Color.red.opacity(0.8) : Color.white.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Background Style
                VStack(alignment: .leading, spacing: 6) {
                    Text("Arka Plan Stili")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    Picker("Stil", selection: $bgMode) {
                        Text("Yarı Saydam").tag("semi_black")
                        Text("Opak Siyah").tag("solid_black")
                        Text("Kutusuz").tag("shadow_only")
                    }
                    .pickerStyle(.segmented)
                }

                // Vertical Offset
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dikey Konum")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    Picker("Konum", selection: $bottomOffset) {
                        Text("Standart (Alt)").tag(0.0)
                        Text("Yukarıda (+30)").tag(30.0)
                    }
                    .pickerStyle(.segmented)
                }

                // Reset Button
                Button(action: resetToDefaults) {
                    Text("Varsayılana Sıfırla")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Color(hex: "1F1F24"))
            .cornerRadius(16)
            .padding(.horizontal, 24)
            .shadow(radius: 20)
        }
    }

    private var previewBgColor: Color {
        switch bgMode {
        case "solid_black": return Color.black
        case "shadow_only": return Color.clear
        default: return Color.black.opacity(0.75)
        }
    }

    private func resetToDefaults() {
        fontSize = 18.0
        colorHex = "FFD700"
        bgMode = "semi_black"
        bottomOffset = 0.0
    }
}
