import SwiftUI

public struct HomeView: View {
    @StateObject private var api = AniziumAPI.shared
    @State private var homeData: HomeResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedAnimeId: String?
    @State private var isFetchingRandom = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.red)
                            .scaleEffect(1.2)
                        Text("Anizium yükleniyor...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Button("Tekrar Dene") {
                            loadData()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                } else if let data = homeData {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Top Featured Slider
                            if let topItems = data.settlement_top, !topItems.isEmpty {
                                HeroCarouselView(items: topItems) { item in
                                    selectedAnimeId = item.ID
                                }
                            }

                            // Special Categories (Popular, Last Added, etc.)
                            if let lists = data.special_list {
                                ForEach(lists) { list in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(list.name)
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: 14) {
                                                ForEach(list.data) { anime in
                                                    Button(action: {
                                                        selectedAnimeId = anime.ID
                                                    }) {
                                                        AnimeCardView(anime: anime, width: 125)
                                                    }
                                                    .buttonStyle(ScaleButtonStyle())
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }

                            // Middle / Lower Settlement rows
                            if let middle = data.settlement_middle, !middle.isEmpty {
                                SettlementRowView(title: "Öne Çıkan Koleksiyonlar", items: middle) { item in
                                    selectedAnimeId = item.ID
                                }
                            }

                            Spacer(minLength: 40)
                        }
                    }
                    .refreshable {
                        await loadDataAsync()
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedAnimeId != nil },
                set: { if !$0 { selectedAnimeId = nil } }
            )) {
                if let id = selectedAnimeId {
                    AnimeDetailView(animeId: id)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("ANIZIUM")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: openRandomAnime) {
                        if isFetchingRandom {
                            ProgressView()
                                .tint(.red)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isFetchingRandom)
                }
            }
        }
        .onAppear {
            if homeData == nil {
                loadData()
            }
        }
    }

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        do {
            let res = try await api.fetchHome()
            await MainActor.run {
                self.homeData = res
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func openRandomAnime() {
        isFetchingRandom = true
        Task {
            do {
                let id = try await api.fetchRandomAnimeId()
                await MainActor.run {
                    self.isFetchingRandom = false
                    self.selectedAnimeId = id
                }
            } catch {
                await MainActor.run {
                    self.isFetchingRandom = false
                }
            }
        }
    }
}

struct SettlementRowView: View {
    let title: String
    let items: [SettlementItem]
    let onSelect: (SettlementItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        Button(action: { onSelect(item) }) {
                            ZStack(alignment: .bottomLeading) {
                                CachedAsyncImage(
                                    url: URL(string: item.banner ?? item.poster ?? ""),
                                    targetSize: CGSize(width: 520, height: 280)
                                ) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color(hex: "1A1A20"))
                                }
                                .frame(width: 260, height: 140)
                                .cornerRadius(10)
                                .clipped()

                                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                    .cornerRadius(10)

                                Text(item.name ?? "")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(10)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
