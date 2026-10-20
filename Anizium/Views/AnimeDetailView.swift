import SwiftUI

public struct AnimeDetailView: View {
    public let animeId: String

    @StateObject private var api = AniziumAPI.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var detail: AnimeDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSeasonIndex = 0
    @State private var playingEpisode: Episode?
    @State private var isPlayingMovie = false
    @State private var isSavedInWatchlist = false

    // Comments State
    @State private var comments: [CommentItem] = []
    @State private var isLoadingComments = false
    @State private var newCommentText = ""
    @State private var isSpoilerComment = false
    @State private var isSendingComment = false
    @State private var showLoginSheet = false
    @State private var showPremiumAlert = false
    @State private var showPremiumPlans = false
    @State private var revealedSpoilers: Set<String> = []

    public init(animeId: String) {
        self.animeId = animeId
    }

    public var body: some View {
        ZStack {
            Color(hex: "0E0E10").ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.red)
                    .scaleEffect(1.2)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.white.opacity(0.8))
                    Button("Tekrar Dene") { loadDetail() }
                        .foregroundColor(.red)
                }
            } else if let anime = detail {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header Banner
                        ZStack(alignment: .bottomLeading) {
                            CachedAsyncImage(
                                url: URL(string: anime.details_banner ?? anime.banner ?? anime.poster ?? ""),
                                targetSize: CGSize(width: 800, height: 480)
                            ) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color(hex: "1F1F24"))
                            }
                            .frame(height: 260)
                            .clipped()

                            LinearGradient(
                                colors: [.clear, Color(hex: "0E0E10")],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            // Title & Quick Info on Header
                            HStack(alignment: .bottom, spacing: 14) {
                                CachedAsyncImage(
                                    url: URL(string: anime.poster ?? ""),
                                    targetSize: CGSize(width: 180, height: 260)
                                ) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 90, height: 130)
                                .cornerRadius(8)
                                .shadow(radius: 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(anime.name ?? "")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    if let jp = anime.name_jp, !jp.isEmpty {
                                        Text(jp)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 8) {
                                        if let year = anime.release_year?.stringValue {
                                            Text(year)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.12))
                                                .cornerRadius(4)
                                        }

                                        if let q = anime.quality {
                                            Text(q.uppercased())
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.15))
                                                .cornerRadius(4)
                                        }

                                        if let rating = anime.rating, !rating.isEmpty {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.yellow)
                                                Text(rating)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }

                        // Action Buttons: İzle & Listeme Ekle
                        HStack(spacing: 12) {
                            if anime.type == "movie" || anime.seasons == nil || anime.seasons?.isEmpty == true {
                                Button(action: {
                                    isPlayingMovie = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("Filmi Oynat")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                            } else if let firstEp = anime.seasons?.first?.episodes?.first {
                                Button(action: {
                                    playingEpisode = firstEp
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("1. Bölümü Oynat")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                            }

                            Button(action: {
                                toggleWatchlist()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isSavedInWatchlist ? "bookmark.fill" : "bookmark")
                                    Text(isSavedInWatchlist ? "Listede" : "Listeme Ekle")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Synopsis / Overview
                        if let overview = anime.overview, !overview.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Özet")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text(overview)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Seasons & Episodes
                        if let seasons = anime.seasons, !seasons.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Bölümler")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)

                                if seasons.count > 1 {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(Array(seasons.enumerated()), id: \.offset) { idx, s in
                                                Button(action: {
                                                    selectedSeasonIndex = idx
                                                }) {
                                                    Text(s.name ?? "Sezon \(s.seasonNumber)")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(selectedSeasonIndex == idx ? .white : .white.opacity(0.6))
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 8)
                                                        .background(selectedSeasonIndex == idx ? Color.red : Color.white.opacity(0.1))
                                                        .cornerRadius(20)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }

                                let currentSeason = seasons[safe: selectedSeasonIndex] ?? seasons[0]
                                if let episodes = currentSeason.episodes {
                                    LazyVStack(spacing: 12) {
                                        ForEach(episodes) { ep in
                                            Button(action: {
                                                playingEpisode = ep
                                            }) {
                                                EpisodeRowView(
                                                    episode: ep,
                                                    animeId: animeId,
                                                    onDownload: {
                                                        handleEpisodeDownload(ep)
                                                    },
                                                    isDownloaded: downloadManager.isDownloaded(id: ep.id),
                                                    isDownloading: downloadManager.isDownloading(id: ep.id)
                                                )
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Comments Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Yorumlar")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(comments.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)

                            // Add Comment Bar
                            if auth.isLoggedIn {
                                VStack(spacing: 8) {
                                    HStack(spacing: 10) {
                                        TextField("Yorumunuzu yazın...", text: $newCommentText)
                                            .padding(10)
                                            .background(Color(hex: "1F1F24"))
                                            .cornerRadius(8)
                                            .foregroundColor(.white)

                                        Button(action: sendCommentAction) {
                                            if isSendingComment {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "paperplane.fill")
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(Color.red)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingComment)
                                    }

                                    Toggle("Spoiler içeriyor", isOn: $isSpoilerComment)
                                        .tint(.red)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                            } else {
                                Button(action: { showLoginSheet = true }) {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                        Text("Yorum yapmak için giriş yapın")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "1F1F24"))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 16)
                            }

                            // Comments List
                            if isLoadingComments {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            } else if comments.isEmpty {
                                Text("Henüz yorum yapılmamış. İlk yorumu sen yaz!")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 16)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(comments) { comment in
                                        CommentRowView(
                                            comment: comment,
                                            isSpoilerRevealed: revealedSpoilers.contains(comment.id),
                                            onToggleSpoiler: {
                                                if revealedSpoilers.contains(comment.id) {
                                                    revealedSpoilers.remove(comment.id)
                                                } else {
                                                    revealedSpoilers.insert(comment.id)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .fullScreenCover(item: $playingEpisode) { ep in
            if let anime = detail {
                let sNum = (anime.seasons?[safe: selectedSeasonIndex]?.seasonNumber) ?? 1
                let saved = UserDefaults.standard.double(forKey: "saved_time_\(anime.ID)_s\(sNum)_e\(ep.episodeNumber)")
                PlayerView(
                    animeId: anime.ID,
                    seasonNumber: sNum,
                    episode: ep,
                    animeTitle: anime.name ?? "",
                    isMovie: false,
                    startTime: saved > 0 ? saved : UserDefaults.standard.double(forKey: "saved_time_\(anime.ID)"),
                    episodes: anime.seasons?[safe: selectedSeasonIndex]?.episodes
                )
            }
        }
        .fullScreenCover(isPresented: $isPlayingMovie) {
            if let anime = detail {
                let saved = UserDefaults.standard.double(forKey: "saved_time_\(anime.ID)_movie")
                PlayerView(
                    animeId: anime.ID,
                    animeTitle: anime.name ?? "",
                    isMovie: true,
                    startTime: saved > 0 ? saved : UserDefaults.standard.double(forKey: "saved_time_\(anime.ID)")
                )
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheetView()
        }
        .alert("Premium Özellik", isPresented: $showPremiumAlert) {
            Button("Planları İncele") {
                showPremiumPlans = true
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Çevrimdışı indirme özelliği yalnızca Anizium Premium üyelerine özeldir. İstediğin bölümleri indirip internetsiz izlemek için Premium'a geçebilirsin.")
        }
        .sheet(isPresented: $showPremiumPlans) {
            PremiumPlansView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDetail()
            checkWatchlist()
            loadComments()
        }
    }

    private func handleEpisodeDownload(_ ep: Episode) {
        if !auth.isLoggedIn {
            showLoginSheet = true
            return
        }
        guard auth.currentUser?.isPremium == true else {
            showPremiumAlert = true
            return
        }
        guard !downloadManager.isDownloaded(id: ep.id) && !downloadManager.isDownloading(id: ep.id) else {
            return
        }

        let seasonNum = (detail?.seasons?[safe: selectedSeasonIndex]?.seasonNumber) ?? 1
        Task {
            try? await downloadManager.downloadEpisode(
                animeId: animeId,
                animeTitle: detail?.name ?? "",
                episode: ep,
                seasonNumber: seasonNum,
                posterURL: ep.banner_link ?? detail?.poster
            )
        }
    }

    private func loadDetail() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let d = try await api.fetchAnimeDetail(id: animeId)
                await MainActor.run {
                    self.detail = d
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadComments() {
        isLoadingComments = true
        Task {
            let res = try? await api.fetchComments(animeId: animeId)
            await MainActor.run {
                self.comments = res ?? []
                self.isLoadingComments = false
            }
        }
    }

    private func sendCommentAction() {
        let msg = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        isSendingComment = true
        Task {
            do {
                try await api.sendComment(animeId: animeId, message: msg, spoiler: isSpoilerComment)
                await MainActor.run {
                    self.newCommentText = ""
                    self.isSendingComment = false
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    self.isSendingComment = false
                }
            }
        }
    }

    private func checkWatchlist() {
        let list = UserDefaults.standard.stringArray(forKey: "watchlist_ids") ?? []
        isSavedInWatchlist = list.contains(animeId)
    }

    private func toggleWatchlist() {
        var list = UserDefaults.standard.stringArray(forKey: "watchlist_ids") ?? []
        if list.contains(animeId) {
            list.removeAll { $0 == animeId }
            isSavedInWatchlist = false
        } else {
            list.append(animeId)
            isSavedInWatchlist = true
        }
        UserDefaults.standard.set(list, forKey: "watchlist_ids")
    }
}

struct CommentRowView: View {
    let comment: CommentItem
    let isSpoilerRevealed: Bool
    let onToggleSpoiler: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatar = comment.profile_avatar, let url = URL(string: avatar) {
                AnimatedGIFView(url: url)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String((comment.user_nick ?? comment.profile_name ?? "A").prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.user_nick ?? comment.profile_name ?? "Anonim")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    if comment.spoiler == true {
                        Text("SPOILER")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(3)
                    }

                    Spacer()

                    if let like = comment.like?.stringValue, like != "0" {
                        HStack(spacing: 3) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 10))
                            Text(like)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                }

                if comment.spoiler == true && !isSpoilerRevealed {
                    Button(action: onToggleSpoiler) {
                        Text("Spoiler içeriyor (Görmek için dokunun)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.9))
                            .padding(6)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(4)
                    }
                } else {
                    Text(comment.message ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "16161B"))
        .cornerRadius(10)
    }
}

struct EpisodeRowView: View {
    let episode: Episode
    var animeId: String = ""
    var onDownload: (() -> Void)? = nil
    var isDownloaded: Bool = false
    var isDownloading: Bool = false

    private var watchProgress: Double {
        guard !animeId.isEmpty else { return 0 }
        return UserDefaults.standard.double(forKey: "watch_prog_\(animeId)_\(episode.id)")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                CachedAsyncImage(
                    url: URL(string: episode.banner_link ?? ""),
                    targetSize: CGSize(width: 240, height: 140)
                ) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(hex: "1F1F24"))
                }
                .frame(width: 120, height: 70)
                .cornerRadius(6)
                .clipped()

                if let runTime = episode.run_time?.stringValue {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(runTime) dk")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(3)
                        }
                        .padding(4)
                        Spacer()
                    }
                    .frame(width: 120, height: 70)
                }

                if watchProgress > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 120, height: 3)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 120 * CGFloat(min(1.0, watchProgress)), height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(episode.episodeNumber). Bölüm")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                if let name = episode.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            if let onDownload = onDownload {
                Button(action: onDownload) {
                    Group {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                                .frame(width: 22, height: 22)
                        } else if isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(6)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
