import SwiftUI
import AVKit
import AVFoundation
import CoreMedia
import Combine

public enum GestureHUDType: Equatable {
    case brightness(Double)
    case volume(Double)

    var iconName: String {
        switch self {
        case .brightness: return "sun.max.fill"
        case .volume: return "speaker.wave.3.fill"
        }
    }

    var title: String {
        switch self {
        case .brightness: return "Parlaklık"
        case .volume: return "Ses Seviyesi"
        }
    }

    var value: Double {
        switch self {
        case .brightness(let v), .volume(let v):
            return v
        }
    }
}

public enum SleepTimerOption: Int, CaseIterable, Identifiable {
    case off = 0
    case min15 = 15
    case min30 = 30
    case min45 = 45
    case min60 = 60
    case endOfEpisode = -1

    public var id: Int { self.rawValue }

    public var title: String {
        switch self {
        case .off: return "Kapalı"
        case .min15: return "15 Dakika"
        case .min30: return "30 Dakika"
        case .min45: return "45 Dakika"
        case .min60: return "60 Dakika"
        case .endOfEpisode: return "Bölüm Bittiğinde"
        }
    }
}

#if os(iOS)
public struct AirPlayButton: UIViewRepresentable {
    public init() {}
    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .white
        picker.activeTintColor = .red
        picker.prioritizesVideoDevices = true
        return picker
    }
    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#else
public struct AirPlayButton: View {
    public init() {}
    public var body: some View {
        EmptyView()
    }
}
#endif

public struct PlayerView: View {
    public let animeId: String
    public let seasonNumber: Int?
    public let episode: Episode?
    public let animeTitle: String
    public let isMovie: Bool
    public let startTime: Double
    public let localURL: URL?
    public let initialEpisodes: [Episode]?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = AniziumAPI.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var downloadManager = DownloadManager.shared

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
        startTime: Double = 0,
        localURL: URL? = nil,
        episodes: [Episode]? = nil
    ) {
        self.animeId = animeId
        self.seasonNumber = seasonNumber
        self.episode = episode
        self.animeTitle = animeTitle
        self.isMovie = isMovie
        self.startTime = startTime
        self.localURL = localURL
        self.initialEpisodes = episodes
    }

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var sourceResponse: SourceResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Episode selection & drawer
    @State private var currentEpisode: Episode?
    @State private var currentSeasonNumber: Int?
    @State private var allEpisodes: [Episode] = []
    @State private var showEpisodesDrawer = false

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
    @State private var isScreenLocked = false
    @State private var showUnlockHint = false
    @State private var unlockHintTimer: Timer?
    @State private var lastSavedSecond: Int = 0

    // Skip Intro & Next Episode state
    @State private var showSkipIntro = false
    @State private var introEndTime: Double = 0
    @State private var showNextEpisode = false

    // Subtitle state
    @State private var subtitles: [SubtitleCue] = []
    @State private var currentSubtitleText: String = ""
    @State private var selectedSubtitle: SubtitleItem?

    // Gesture & HUD States
    @State private var seekIndicatorForward: Bool? = nil
    @State private var seekIndicatorTimer: Timer?
    @State private var gestureHUD: GestureHUDType? = nil
    @State private var gestureHUDTimer: Timer?
    @State private var dragStartValue: Double? = nil

    // Autoplay Next Episode Countdown
    @State private var showAutoplayOverlay = false
    @State private var autoplayCountdown: Int = 5
    @State private var autoplayTimer: Timer?
    @State private var isAutoplayCancelled = false

    // Sleep Timer
    @State private var sleepTimer: SleepTimerOption = .off
    @State private var sleepTimerSecondsRemaining: Int = 0
    @State private var sleepTimerTask: Timer?

    // Premium Prompt Modal / Sheet
    @State private var showPremiumAlert = false
    @State private var showPremiumPlans = false
    @State private var showLoginSheet = false
    @AppStorage("player_aspect_fill") private var isAspectFill: Bool = true

    private var getResumeTime: Double {
        if startTime > 0 { return startTime }
        let id = animeId
        if isMovie {
            let movieSaved = UserDefaults.standard.double(forKey: "saved_time_\(id)_movie")
            if movieSaved > 0 { return movieSaved }
            return UserDefaults.standard.double(forKey: "saved_time_\(id)")
        } else {
            let s = currentSeasonNumber ?? seasonNumber ?? 1
            let e = currentEpisode?.episodeNumber ?? episode?.episodeNumber ?? 1
            let epSaved = UserDefaults.standard.double(forKey: "saved_time_\(id)_s\(s)_e\(e)")
            if epSaved > 0 { return epSaved }
            return UserDefaults.standard.double(forKey: "saved_time_\(id)")
        }
    }

    private var subtitleBgColor: Color {
        switch subBgMode {
        case "solid_black": return Color.black
        case "shadow_only": return Color.clear
        default: return Color.black.opacity(0.75)
        }
    }

    private var playerTitle: String {
        if let ep = currentEpisode {
            return "\(animeTitle) - \(ep.episodeNumber). Bölüm"
        }
        return animeTitle
    }

    public var body: some View {
        GeometryReader { geo in
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
                    // Video Surface (Full Screen forced aspect fill on iPad/iOS by default)
                    CustomVideoPlayer(player: player, videoGravity: isAspectFill ? .resizeAspectFill : .resizeAspect)
                        .ignoresSafeArea()
                        .edgesIgnoringSafeArea(.all)

                    // Touch & Gesture Interaction Layer
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2, coordinateSpace: .local) { loc in
                            guard !isScreenLocked else { return }
                            let isRight = loc.x > (geo.size.width / 2)
                            handleDoubleTapSeek(isForward: isRight)
                        }
                        .onTapGesture(count: 1) {
                            handleSingleTap()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 15)
                                .onChanged { val in
                                    guard !isScreenLocked else { return }
                                    handleVerticalDrag(val, in: geo.size)
                                }
                                .onEnded { _ in
                                    hideGestureHUDWithDelay()
                                }
                        )

                    // Double-Tap Seek Indicators (<< 10s or 10s >>)
                    if let isForward = seekIndicatorForward {
                        HStack {
                            if !isForward {
                                HStack(spacing: 8) {
                                    Image(systemName: "gobackward.10")
                                        .font(.system(size: 26, weight: .bold))
                                    Text("10 sn")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .padding(.leading, 40)
                                Spacer()
                            } else {
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("10 sn")
                                        .font(.system(size: 14, weight: .bold))
                                    Image(systemName: "goforward.10")
                                        .font(.system(size: 26, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .padding(.trailing, 40)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                    }

                    // Brightness & Volume Gesture HUD
                    if let hud = gestureHUD {
                        VStack(spacing: 10) {
                            Image(systemName: hud.iconName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            // Level Bar
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 120, height: 6)

                                Capsule()
                                    .fill(Color.red)
                                    .frame(width: 120 * CGFloat(max(0.0, min(1.0, hud.value))), height: 6)
                            }

                            HStack(spacing: 4) {
                                Text(hud.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(Int(hud.value * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }

                    // Subtitle Display Overlay (Fully Customizable, unaffected by popups)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                        .zIndex(10)
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
                    if showNextEpisode && !showAutoplayOverlay {
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

                    // Autoplay Next Episode Countdown Overlay
                    if showAutoplayOverlay, let nextEp = nextEpisodeItem {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sonraki Bölüm (\(autoplayCountdown)s)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.red)
                                        Text(nextEp.name ?? "\(nextEp.episodeNumber). Bölüm")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }

                                    Button(action: {
                                        playNextEpisode()
                                    }) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                    }

                                    Button(action: cancelAutoplay) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(6)
                                            .background(Color.white.opacity(0.15))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.85))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                )
                                .shadow(color: .red.opacity(0.3), radius: 8)
                                .padding(.trailing, 24)
                                .padding(.bottom, showControls ? 100 : 40)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Player Controls Overlay
                    if showControls && !isScreenLocked {
                        PlayerControlsOverlay(
                            title: playerTitle,
                            isPlaying: $isPlaying,
                            currentTime: $currentTime,
                            duration: duration,
                            hasEpisodes: !isMovie && (allEpisodes.count > 1 || currentEpisode != nil),
                            canDownload: !isMovie && localURL == nil && currentEpisode != nil,
                            isDownloaded: downloadManager.isDownloaded(id: currentEpisode?.id ?? ""),
                            isDownloading: downloadManager.isDownloading(id: currentEpisode?.id ?? ""),
                            sleepTimer: sleepTimer,
                            isAspectFill: isAspectFill,
                            availableGroups: availableGroups,
                            selectedGroup: selectedGroup,
                            availableStreams: availableStreams,
                            selectedStream: selectedStream,
                            playbackRate: playbackRate,
                            subtitles: sourceResponse?.subtitles ?? [],
                            selectedSubtitle: selectedSubtitle,
                            onPlayPause: togglePlayPause,
                            onSeek: seekTo,
                            onToggleEpisodesDrawer: {
                                withAnimation { showEpisodesDrawer.toggle() }
                            },
                            onDownloadTap: handleDownloadTap,
                            onSelectSleepTimer: setSleepTimer,
                            onToggleAspect: {
                                withAnimation { isAspectFill.toggle() }
                            },
                            onSelectGroup: switchAudioGroup,
                            onSelectStream: switchQuality,
                            onSelectSpeed: setPlaybackSpeed,
                            onSelectSubtitle: switchSubtitle,
                            onOpenSubtitleSettings: { showSubtitleSettings = true },
                            onLockScreen: {
                                withAnimation {
                                    isScreenLocked = true
                                    showControls = false
                                    showUnlockHint = true
                                    unlockHintTimer?.invalidate()
                                    unlockHintTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                                        withAnimation { self.showUnlockHint = false }
                                    }
                                }
                            },
                            onTapBackground: {
                                withAnimation {
                                    showControls = false
                                }
                            },
                            onClose: { dismiss() }
                        )
                        .transition(.opacity)
                    }

                    // Quick Episode Drawer
                    if showEpisodesDrawer {
                        HStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Bölümler (\(allEpisodes.count))")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: { withAnimation { showEpisodesDrawer = false } }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(6)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(hex: "17171C"))

                                Divider().background(Color.white.opacity(0.1))

                                if allEpisodes.isEmpty {
                                    VStack(spacing: 8) {
                                        Spacer()
                                        ProgressView().tint(.red)
                                        Text("Bölümler alınıyor...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.6))
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    ScrollView(.vertical, showsIndicators: false) {
                                        LazyVStack(spacing: 8) {
                                            ForEach(allEpisodes) { ep in
                                                let isCurrent = ep.id == currentEpisode?.id
                                                Button(action: {
                                                    selectEpisodeFromDrawer(ep)
                                                }) {
                                                    HStack(spacing: 10) {
                                                        Text("\(ep.episodeNumber)")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
                                                            .frame(width: 26, height: 26)
                                                            .background(isCurrent ? Color.red : Color.white.opacity(0.1))
                                                            .clipShape(Circle())

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(ep.name ?? "\(ep.episodeNumber). Bölüm")
                                                                .font(.system(size: 13, weight: isCurrent ? .bold : .medium))
                                                                .foregroundColor(isCurrent ? .red : .white)
                                                                .lineLimit(1)

                                                            if isCurrent {
                                                                Text("Şu an oynatılıyor")
                                                                    .font(.system(size: 10, weight: .bold))
                                                                    .foregroundColor(.red.opacity(0.8))
                                                            } else {
                                                                let prog = UserDefaults.standard.double(forKey: "watch_prog_\(animeId)_\(ep.id)")
                                                                if prog > 0.03 {
                                                                    ZStack(alignment: .leading) {
                                                                        Capsule().fill(Color.white.opacity(0.2)).frame(width: 80, height: 3)
                                                                        Capsule().fill(Color.red).frame(width: 80 * CGFloat(min(1.0, prog)), height: 3)
                                                                    }
                                                                    .padding(.top, 2)
                                                                }
                                                            }
                                                        }

                                                        Spacer()

                                                        if downloadManager.isDownloaded(id: ep.id) {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.green)
                                                                .font(.system(size: 13))
                                                        }
                                                    }
                                                    .padding(10)
                                                    .background(isCurrent ? Color.red.opacity(0.15) : Color.white.opacity(0.04))
                                                    .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .padding(12)
                                    }
                                }
                            }
                            .frame(width: min(320, geo.size.width * 0.75))
                            .background(Color(hex: "121216"))
                            .shadow(color: .black.opacity(0.8), radius: 20)
                        }
                        .transition(.move(edge: .trailing))
                    }

                    // Screen Lock Floating Unlock Button
                    if isScreenLocked && showUnlockHint {
                        VStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isScreenLocked = false
                                    showUnlockHint = false
                                    showControls = true
                                    resetControlsTimer()
                                }
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Ekran Kilidini Aç")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.red, lineWidth: 1.5)
                                )
                                .cornerRadius(24)
                                .shadow(color: .red.opacity(0.5), radius: 10)
                            }
                            .padding(.bottom, 36)
                        }
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
        }
        .onAppear {
            self.currentEpisode = episode
            self.currentSeasonNumber = seasonNumber
            if let eps = initialEpisodes, !eps.isEmpty {
                self.allEpisodes = eps
            } else if !isMovie {
                fetchEpisodesForDrawer()
            }

            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            loadSource()
        }
        .onDisappear {
            saveKeepWatchingProgress()
            cleanUpPlayer()
        }
        .alert("Premium Özellik", isPresented: $showPremiumAlert) {
            Button("Planları İncele") {
                showPremiumPlans = true
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Çevrimdışı izleme özelliği yalnızca Anizium Premium üyelerine özeldir. Bölümleri cihazınıza indirip internetsiz izlemek için Premium'a geçebilirsiniz.")
        }
        .sheet(isPresented: $showPremiumPlans) {
            PremiumPlansView()
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheetView()
        }
    }

    // MARK: - Gestures & Interactions
    private func handleSingleTap() {
        if isScreenLocked {
            withAnimation {
                showUnlockHint.toggle()
                if showUnlockHint {
                    unlockHintTimer?.invalidate()
                    unlockHintTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                        withAnimation { self.showUnlockHint = false }
                    }
                }
            }
        } else {
            withAnimation {
                if showEpisodesDrawer {
                    showEpisodesDrawer = false
                } else {
                    showControls.toggle()
                    if showControls { resetControlsTimer() }
                }
            }
        }
    }

    private func handleDoubleTapSeek(isForward: Bool) {
        let delta: Double = isForward ? 10.0 : -10.0
        seekTo(max(0, min(duration, currentTime + delta)))
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            self.seekIndicatorForward = isForward
        }
        seekIndicatorTimer?.invalidate()
        seekIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                self.seekIndicatorForward = nil
            }
        }
    }

    private func handleVerticalDrag(_ value: DragGesture.Value, in size: CGSize) {
        let isLeft = value.startLocation.x < (size.width / 2)
        if dragStartValue == nil {
            #if os(iOS)
            dragStartValue = isLeft ? Double(UIScreen.main.brightness) : Double(player?.volume ?? 1.0)
            #else
            dragStartValue = Double(player?.volume ?? 1.0)
            #endif
        }
        let delta = -Double(value.translation.height / (size.height * 0.55))
        let newVal = max(0.0, min(1.0, (dragStartValue ?? 0.5) + delta))

        if isLeft {
            #if os(iOS)
            UIScreen.main.brightness = CGFloat(newVal)
            #endif
            showGestureHUD(.brightness(newVal))
        } else {
            player?.volume = Float(newVal)
            showGestureHUD(.volume(newVal))
        }
    }

    private func showGestureHUD(_ type: GestureHUDType) {
        self.gestureHUD = type
        gestureHUDTimer?.invalidate()
    }

    private func hideGestureHUDWithDelay() {
        dragStartValue = nil
        gestureHUDTimer?.invalidate()
        gestureHUDTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                self.gestureHUD = nil
            }
        }
    }

    private func selectEpisodeFromDrawer(_ ep: Episode) {
        cleanUpPlayer()
        cancelAutoplay()
        self.isAutoplayCancelled = false
        self.currentEpisode = ep
        self.currentTime = 0
        self.duration = 0
        withAnimation {
            self.showEpisodesDrawer = false
        }
        loadSource()
    }

    private var nextEpisodeItem: Episode? {
        guard let cur = currentEpisode else { return nil }
        return allEpisodes.first(where: { $0.episodeNumber == cur.episodeNumber + 1 })
    }

    private func startAutoplayCountdown() {
        guard !showAutoplayOverlay, !isAutoplayCancelled, nextEpisodeItem != nil else { return }
        showAutoplayOverlay = true
        autoplayCountdown = 5
        autoplayTimer?.invalidate()
        autoplayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.autoplayCountdown > 1 {
                self.autoplayCountdown -= 1
            } else {
                timer.invalidate()
                self.showAutoplayOverlay = false
                self.playNextEpisode()
            }
        }
    }

    private func cancelAutoplay() {
        showAutoplayOverlay = false
        isAutoplayCancelled = true
        autoplayTimer?.invalidate()
        autoplayTimer = nil
    }

    private func playNextEpisode() {
        cancelAutoplay()
        if let next = nextEpisodeItem {
            selectEpisodeFromDrawer(next)
        } else {
            dismiss()
        }
    }

    private func setSleepTimer(_ option: SleepTimerOption) {
        self.sleepTimer = option
        sleepTimerTask?.invalidate()
        sleepTimerTask = nil

        if option == .off || option == .endOfEpisode {
            sleepTimerSecondsRemaining = 0
            return
        }

        sleepTimerSecondsRemaining = option.rawValue * 60
        sleepTimerTask = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.sleepTimerSecondsRemaining > 1 {
                self.sleepTimerSecondsRemaining -= 1
            } else {
                timer.invalidate()
                self.triggerSleepTimer()
            }
        }
    }

    private func triggerSleepTimer() {
        sleepTimerTask?.invalidate()
        sleepTimer = .off
        player?.pause()
        isPlaying = false
        showGestureHUD(.volume(0))
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    private func handleDownloadTap() {
        if !auth.isLoggedIn {
            showLoginSheet = true
            return
        }
        guard auth.currentUser?.isPremium == true else {
            showPremiumAlert = true
            return
        }
        guard let ep = currentEpisode else { return }
        if downloadManager.isDownloaded(id: ep.id) || downloadManager.isDownloading(id: ep.id) {
            return
        }

        if let stream = selectedStream, let videoURL = URL(string: stream.link) {
            downloadManager.startDownload(
                animeId: animeId,
                animeTitle: animeTitle,
                episode: ep,
                videoURL: videoURL,
                posterURL: ep.banner_link
            )
        } else {
            Task {
                try? await downloadManager.downloadEpisode(
                    animeId: animeId,
                    animeTitle: animeTitle,
                    episode: ep,
                    seasonNumber: currentSeasonNumber ?? 1,
                    posterURL: ep.banner_link
                )
            }
        }
    }

    private func fetchEpisodesForDrawer() {
        Task {
            if let detail = try? await api.fetchAnimeDetail(id: animeId) {
                let season = detail.seasons?.first(where: { $0.seasonNumber == self.currentSeasonNumber }) ?? detail.seasons?.first
                await MainActor.run {
                    self.allEpisodes = season?.episodes ?? []
                }
            }
        }
    }

    // MARK: - Player Actions
    private func loadSource() {
        if let local = localURL {
            self.isLoading = false
            initAVPlayer(url: local, startAt: getResumeTime)
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                let res: SourceResponse
                if isMovie || currentEpisode == nil {
                    res = try await api.fetchMovieSource(id: animeId)
                } else {
                    res = try await api.fetchSource(
                        id: animeId,
                        season: currentSeasonNumber ?? 1,
                        episode: currentEpisode?.episodeNumber ?? 1
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
        setupStreamsForGroup(defaultGroup, resumeAt: getResumeTime)

        // Subtitles setup (load Turkish sub if available or first sub)
        if let subs = res.subtitles, !subs.isEmpty {
            let preferredSub = subs.first(where: { ($0.group ?? "").lowercased().contains("tr") || ($0.name ?? "").lowercased().contains("türk") }) ?? subs.first
            if defaultGroup.group != "trdub" || subs.count == 1 {
                self.selectedSubtitle = preferredSub
                if let link = preferredSub?.link {
                    loadSubtitles(from: link)
                }
            }
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

        if let url = URL(string: best.link) {
            initAVPlayer(url: url, startAt: resumeAt)
        }
    }

    private func initAVPlayer(url: URL, startAt: Double = 0) {
        let playerItem = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: playerItem)
        self.player = p
        self.isLoading = false

        let effectiveStart = startAt > 0 ? startAt : getResumeTime
        if effectiveStart > 3 {
            if playerItem.status == .readyToPlay {
                p.seek(to: CMTime(seconds: effectiveStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            } else {
                var observer: NSKeyValueObservation?
                observer = playerItem.observe(\.status, options: [.new]) { item, _ in
                    if item.status == .readyToPlay {
                        p.seek(to: CMTime(seconds: effectiveStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                        observer?.invalidate()
                        observer = nil
                    }
                }
            }
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

        if let url = URL(string: matching.link) {
            initAVPlayer(url: url, startAt: currentPos)
        }
    }

    private func switchQuality(to stream: StreamItem) {
        guard stream.link != selectedStream?.link else { return }
        let currentPos = currentTime
        selectedStream = stream
        cleanUpPlayer()
        if let url = URL(string: stream.link) {
            initAVPlayer(url: url, startAt: currentPos)
        }
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
        let season = currentSeasonNumber ?? seasonNumber
        let ep = currentEpisode?.episodeNumber ?? episode?.episodeNumber

        if isMovie {
            UserDefaults.standard.set(time, forKey: "saved_time_\(id)_movie")
            UserDefaults.standard.set(time, forKey: "saved_time_\(id)")
            if duration > 0 {
                let ratio = min(1.0, max(0.0, time / duration))
                UserDefaults.standard.set(ratio, forKey: "watch_prog_\(id)_movie")
                UserDefaults.standard.set(ratio, forKey: "watch_prog_\(id)")
            }
        } else {
            if let s = season, let e = ep {
                UserDefaults.standard.set(time, forKey: "saved_time_\(id)_s\(s)_e\(e)")
            }
            UserDefaults.standard.set(time, forKey: "saved_time_\(id)")
            if let epId = currentEpisode?.id ?? episode?.id, duration > 0 {
                let ratio = min(1.0, max(0.0, time / duration))
                UserDefaults.standard.set(ratio, forKey: "watch_prog_\(id)_\(epId)")
            }
        }

        Task {
            try? await api.saveKeepWatching(
                id: id,
                season: isMovie ? nil : season,
                episode: isMovie ? nil : ep,
                time: time
            )
        }
    }

    private func checkIntroAndOutro(currentTime: Double) {
        // Sleep Timer: End of Episode check
        if sleepTimer == .endOfEpisode && duration > 10 && currentTime >= (duration - 1.5) {
            triggerSleepTimer()
            return
        }

        // Autoplay Next Episode Countdown: trigger within last 12 seconds
        if !isMovie && nextEpisodeItem != nil && sleepTimer != .endOfEpisode && duration > 20 && currentTime >= (duration - 12) {
            if !showAutoplayOverlay && !isAutoplayCancelled {
                startAutoplayCountdown()
            }
        }

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

    // MARK: - Subtitles (WebVTT & SRT)
    private func loadSubtitles(from urlStr: String) {
        var cleanUrl = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasPrefix("//") {
            cleanUrl = "https:" + cleanUrl
        } else if !cleanUrl.hasPrefix("http://") && !cleanUrl.hasPrefix("https://") {
            cleanUrl = "https://api.anizium.co" + (cleanUrl.hasPrefix("/") ? "" : "/") + cleanUrl
        }
        guard let url = URL(string: cleanUrl) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let str = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .windowsCP1254)
                    ?? String(data: data, encoding: .isoLatin1)
                    ?? String(decoding: data, as: UTF8.self)
                let parsed = parseWebVTT(str)
                await MainActor.run {
                    self.subtitles = parsed
                }
            } catch {
                print("Subtitle load error: \(error)")
            }
        }
    }

    private func updateSubtitle(currentTime: Double) {
        if let match = subtitles.first(where: { currentTime >= $0.start && currentTime <= $0.end }) {
            if self.currentSubtitleText != match.text {
                self.currentSubtitleText = match.text
            }
        } else {
            if !self.currentSubtitleText.isEmpty {
                self.currentSubtitleText = ""
            }
        }
    }

    private func parseWebVTT(_ text: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count == 2,
                   let start = parseVttTimestamp(parts[0]),
                   let end = parseVttTimestamp(parts[1].components(separatedBy: " ").first ?? "") {
                    i += 1
                    var cueLines: [String] = []
                    while i < lines.count {
                        let textLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if textLine.isEmpty { break }
                        if textLine.contains("-->") {
                            i -= 1
                            break
                        }
                        // Strip WebVTT/HTML formatting tags
                        let clean = textLine.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        if !clean.isEmpty {
                            cueLines.append(clean)
                        }
                        i += 1
                    }
                    if !cueLines.isEmpty {
                        cues.append(SubtitleCue(start: start, end: end, text: cueLines.joined(separator: "\n")))
                    }
                }
            }
            i += 1
        }
        return cues
    }

    private func parseVttTimestamp(_ s: String) -> Double? {
        let clean = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = clean.split(separator: ":").compactMap { sub -> Double? in
            let str = String(sub).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(str)
        }
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
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = videoGravity
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.videoGravity != videoGravity {
            uiViewController.videoGravity = videoGravity
        }
    }
}

// Overlay Controls
struct PlayerControlsOverlay: View {
    let title: String
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    let duration: Double

    let hasEpisodes: Bool
    let canDownload: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let sleepTimer: SleepTimerOption
    let isAspectFill: Bool

    let availableGroups: [SourceGroup]
    let selectedGroup: SourceGroup?
    let availableStreams: [StreamItem]
    let selectedStream: StreamItem?
    let playbackRate: Float
    let subtitles: [SubtitleItem]
    let selectedSubtitle: SubtitleItem?

    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onToggleEpisodesDrawer: () -> Void
    let onDownloadTap: () -> Void
    let onSelectSleepTimer: (SleepTimerOption) -> Void
    let onToggleAspect: () -> Void
    let onSelectGroup: (SourceGroup) -> Void
    let onSelectStream: (StreamItem) -> Void
    let onSelectSpeed: (Float) -> Void
    let onSelectSubtitle: (SubtitleItem?) -> Void
    let onOpenSubtitleSettings: () -> Void
    let onLockScreen: () -> Void
    let onTapBackground: () -> Void
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
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapBackground()
                }

            VStack {
                // Top Header
                HStack(spacing: 10) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Quick Episodes Drawer Button
                    if hasEpisodes {
                        Button(action: onToggleEpisodesDrawer) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 11))
                                Text("Bölümler")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(5)
                        }
                    }

                    // Download Button
                    if canDownload {
                        Button(action: onDownloadTap) {
                            HStack(spacing: 4) {
                                if isDownloading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.6)
                                        .frame(width: 11, height: 11)
                                } else {
                                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(isDownloaded ? .green : .white)
                                }
                                Text(isDownloaded ? "İndirildi" : "İndir")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isDownloaded ? .green : .white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isDownloaded ? Color.green.opacity(0.2) : Color.white.opacity(0.2))
                            .cornerRadius(5)
                        }
                    }

                    // Screen Lock Button
                    Button(action: onLockScreen) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Kilitle")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(5)
                    }

                    // Aspect Mode Button (Tam Ekran Doldur / Sığdır)
                    Button(action: onToggleAspect) {
                        HStack(spacing: 4) {
                            Image(systemName: isAspectFill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11))
                            Text(isAspectFill ? "Tam Ekran" : "Sığdır")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isAspectFill ? Color.red.opacity(0.8) : Color.white.opacity(0.2))
                        .cornerRadius(5)
                    }

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

                    // Sleep Timer Menu
                    Menu {
                        ForEach(SleepTimerOption.allCases) { opt in
                            Button(action: { onSelectSleepTimer(opt) }) {
                                HStack {
                                    Text(opt.title)
                                    if sleepTimer == opt {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: sleepTimer != .off ? "moon.fill" : "moon")
                            .font(.system(size: 14))
                            .foregroundColor(sleepTimer != .off ? .yellow : .white)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    // AirPlay TV Picker
                    AirPlayButton()
                        .frame(width: 28, height: 28)
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
