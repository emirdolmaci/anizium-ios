import SwiftUI

public struct AnimeDetailView: View {
    public let animeId: String

    @StateObject private var api = AniziumAPI.shared
    @State private var detail: AnimeDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSeasonIndex = 0
    @State private var playingEpisode: Episode?
    @State private var isSavedInWatchlist = false

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
                    VStack(alignment: .leading, spacing: 16) {
                        // Header Banner
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: anime.details_banner ?? anime.banner ?? anime.poster ?? "")) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(Color(hex: "1F1F24"))
                                }
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
                                AsyncImage(url: URL(string: anime.poster ?? "")) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
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
                            if let firstEp = anime.seasons?.first?.episodes?.first {
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

                                // Season Tabs if multiple seasons
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

                                // Episodes list for current season
                                let currentSeason = seasons[safe: selectedSeasonIndex] ?? seasons[0]
                                if let episodes = currentSeason.episodes {
                                    LazyVStack(spacing: 12) {
                                        ForEach(episodes) { ep in
                                            Button(action: {
                                                playingEpisode = ep
                                            }) {
                                                EpisodeRowView(episode: ep)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .fullScreenCover(item: $playingEpisode) { ep in
            if let anime = detail {
                PlayerView(
                    animeId: anime.ID,
                    seasonNumber: (anime.seasons?[safe: selectedSeasonIndex]?.seasonNumber) ?? 1,
                    episode: ep,
                    animeTitle: anime.name ?? ""
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDetail()
            checkWatchlist()
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

struct EpisodeRowView: View {
    let episode: Episode

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: episode.banner_link ?? "")) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(hex: "1F1F24"))
                    }
                }
                .frame(width: 120, height: 70)
                .cornerRadius(6)
                .clipped()

                if let runTime = episode.run_time?.stringValue {
                    Text("\(runTime) dk")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(3)
                        .padding(4)
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
