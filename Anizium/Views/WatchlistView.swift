import SwiftUI

public struct WatchlistView: View {
    @StateObject private var api = AniziumAPI.shared
    @State private var savedAnime: [AnimeDetail] = []
    @State private var isLoading = false
    @State private var selectedAnimeId: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.red)
                } else if savedAnime.isEmpty {
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
            }
            .navigationTitle("Listem")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { selectedAnimeId != nil },
                set: { if !$0 { selectedAnimeId = nil } }
            )) {
                if let id = selectedAnimeId {
                    AnimeDetailView(animeId: id)
                }
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
