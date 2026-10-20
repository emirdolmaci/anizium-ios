import SwiftUI

public struct WatchlistView: View {
    @StateObject private var api = AniziumAPI.shared
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var selectedTab = 0 // 0: Listem, 1: İndirilenler
    @State private var savedAnime: [AnimeDetail] = []
    @State private var isLoading = false
    @State private var selectedAnimeId: String?
    @State private var playingDownloadedItem: DownloadItem?

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 14)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Tab Picker
                    Picker("Görünüm", selection: $selectedTab) {
                        Text("Listem (\(savedAnime.count))").tag(0)
                        Text("İndirilenler (\(downloadManager.downloads.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedTab == 0 {
                        // Watchlist Tab
                        if isLoading {
                            Spacer()
                            ProgressView().tint(.red)
                            Spacer()
                        } else if savedAnime.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Listeniz henüz boş")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Beğendiğiniz animeleri detay sayfasından listenize ekleyebilirsiniz.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            Spacer()
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(savedAnime) { anime in
                                        Button(action: {
                                            selectedAnimeId = anime.ID
                                        }) {
                                            let card = AnimeCard(
                                                ID: anime.ID,
                                                name: anime.name,
                                                poster: anime.poster,
                                                banner: anime.banner,
                                                banner_link: anime.banner,
                                                logo: anime.logo,
                                                quality: anime.quality,
                                                type: anime.type,
                                                tmdb_point: anime.tmdb_point,
                                                imdb_point: anime.imdb_point,
                                                mal_point: anime.mal_point,
                                                episode_count: nil,
                                                series: anime.type,
                                                total_season: anime.total_season,
                                                release_year: anime.release_year
                                            )
                                            AnimeCardView(anime: card, width: 110)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                            }
                        }
                    } else {
                        // Downloads Tab (Offline)
                        if downloadManager.downloads.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("İndirilen Bölüm Yok")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Bölümleri cihazınıza indirerek internetiniz olmadığında da kesintisiz izleyebilirsiniz.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            Spacer()
                        } else {
                            List {
                                ForEach(downloadManager.downloads) { item in
                                    DownloadedEpisodeRow(
                                        item: item,
                                        onPlay: {
                                            if item.isCompleted && item.localURL != nil {
                                                playingDownloadedItem = item
                                            }
                                        },
                                        onDelete: {
                                            downloadManager.deleteDownload(id: item.id)
                                        }
                                    )
                                    .listRowBackground(Color(hex: "15151B"))
                                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                                }
                                .onDelete { indexSet in
                                    for idx in indexSet {
                                        let item = downloadManager.downloads[idx]
                                        downloadManager.deleteDownload(id: item.id)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Listem & İndirilenler")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { selectedAnimeId != nil },
                set: { if !$0 { selectedAnimeId = nil } }
            )) {
                if let id = selectedAnimeId {
                    AnimeDetailView(animeId: id)
                }
            }
            .fullScreenCover(item: $playingDownloadedItem) { item in
                PlayerView(
                    animeId: item.animeId,
                    episode: Episode(
                        ID: item.id,
                        name: item.episodeTitle,
                        number: StringOrNumber(item.episodeNumber),
                        overview: nil,
                        release: nil,
                        run_time: nil,
                        quality: nil,
                        banner_link: item.posterURL,
                        next_episode: nil,
                        download: nil
                    ),
                    animeTitle: item.animeTitle,
                    isMovie: false,
                    localURL: item.localURL
                )
            }
            .onAppear {
                loadSavedList()
            }
        }
    }

    private func loadSavedList() {
        let list = UserDefaults.standard.stringArray(forKey: "watchlist_ids") ?? []
        guard !list.isEmpty else {
            savedAnime = []
            return
        }

        isLoading = true
        Task {
            var loaded: [AnimeDetail] = []
            for id in list {
                if let detail = try? await api.fetchAnimeDetail(id: id) {
                    loaded.append(detail)
                }
            }
            await MainActor.run {
                self.savedAnime = loaded
                self.isLoading = false
            }
        }
    }
}

struct DownloadedEpisodeRow: View {
    let item: DownloadItem
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let poster = item.posterURL, let url = URL(string: poster) {
                    CachedAsyncImage(url: url, targetSize: CGSize(width: 160, height: 100)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(hex: "23232A"))
                    }
                } else {
                    Rectangle().fill(Color(hex: "23232A"))
                }
            }
            .frame(width: 90, height: 56)
            .cornerRadius(6)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.animeTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(item.episodeNumber). Bölüm • \(item.episodeTitle)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if item.isCompleted {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("İnternetsiz İzle • \(item.fileSizeString)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                .scaleEffect(0.6)
                                .frame(width: 10, height: 10)
                            Text(item.fileSizeString)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }

            Spacer()

            // Play or Delete
            if item.isCompleted {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(6)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
