import SwiftUI

public struct SearchView: View {
    @StateObject private var api = AniziumAPI.shared
    @State private var searchText = ""
    @State private var searchResults: [AnimeCard] = []
    @State private var isLoading = false
    @State private var selectedAnimeId: String?
    @State private var searchTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                VStack(spacing: 14) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))

                        TextField("Anime, film veya dizi ara...", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { newValue in
                                debounceSearch(query: newValue)
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "1F1F24"))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.red)
                        Spacer()
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Sonuç bulunamadı")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(searchResults) { anime in
                                    Button(action: {
                                        selectedAnimeId = anime.ID
                                    }) {
                                        AnimeCardView(anime: anime, width: 110)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Keşfet")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { selectedAnimeId != nil },
                set: { if !$0 { selectedAnimeId = nil } }
            )) {
                if let id = selectedAnimeId {
                    AnimeDetailView(animeId: id)
                }
            }
        }
    }

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }

            do {
                let results = try await api.search(query: trimmed)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
