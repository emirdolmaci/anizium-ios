import SwiftUI

public struct CalendarView: View {
    @StateObject private var api = AniziumAPI.shared
    @State private var days: [CalendarDay] = []
    @State private var selectedIndex = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedAnimeId: String?

    public init() {}

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
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.red)
                            .scaleEffect(1.2)
                        Text("Yayın takvimi yükleniyor...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        Button("Tekrar Dene") {
                            loadCalendar()
                        }
                        .foregroundColor(.red)
                    }
                } else if days.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Yayın takvimi bulunamadı.")
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    VStack(spacing: 0) {
                        // Day Picker Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                                    Button(action: {
                                        selectedIndex = idx
                                    }) {
                                        VStack(spacing: 4) {
                                            Text(day.day_name ?? day.title ?? "Gün")
                                                .font(.system(size: 14, weight: .bold))
                                            if let title = day.title, title != day.day_name {
                                                Text(title)
                                                    .font(.system(size: 10))
                                                    .opacity(0.8)
                                            }
                                        }
                                        .foregroundColor(selectedIndex == idx ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedIndex == idx ? Color.red : Color(hex: "1A1A20"))
                                        .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "121216"))

                        // Anime Cards Grid
                        ScrollView {
                            let currentDay = days[safe: selectedIndex] ?? days[0]
                            let animes = currentDay.contents ?? []

                            if animes.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 60)
                                    Image(systemName: "tv.slash")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("Bu güne ait yayınlanan anime bulunamadı.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            } else {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(animes) { anime in
                                        Button(action: {
                                            selectedAnimeId = anime.ID
                                        }) {
                                            AnimeCardView(anime: anime, width: 110)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(16)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yayın Takvimi")
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
        .onAppear {
            if days.isEmpty {
                loadCalendar()
            }
        }
    }

    private func loadCalendar() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let res = try await api.fetchCalendar()
                await MainActor.run {
                    self.days = res
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
}
