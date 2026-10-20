import SwiftUI

public struct AvatarPickerView: View {
    public let profileId: String
    public let onAvatarSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var api = AniziumAPI.shared
    @StateObject private var auth = AuthManager.shared

    @State private var groups: [AvatarGroup] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isSetting = false
    @State private var selectedAvatarId: String?
    @State private var currentPage = 1
    @State private var hasNextPage = true
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 14)
    ]

    public init(profileId: String, onAvatarSelected: @escaping () -> Void = {}) {
        self.profileId = profileId
        self.onAvatarSelected = onAvatarSelected
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        TextField("Anime veya karakter ara (Örn: Titan, Luffy)...", text: $searchText)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { val in
                                debounceSearch(query: val)
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                loadInitialAvatars()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "1F1F24"))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if isLoading && groups.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView().tint(.red)
                            Text("Animasyonlu avatarlar yükleniyor...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    } else if groups.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Avatar bulunamadı.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 22) {
                                ForEach(groups) { group in
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Group title / Logo
                                        HStack(spacing: 8) {
                                            if let logoUrl = group.logo, let url = URL(string: logoUrl) {
                                                CachedAsyncImage(url: url, targetSize: CGSize(width: 240, height: 80)) { img in
                                                    img.resizable().scaledToFit().frame(maxHeight: 28)
                                                } placeholder: {
                                                    Text(group.name)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            } else {
                                                Text(group.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)

                                        // Avatars grid
                                        if let avatars = group.avatar, !avatars.isEmpty {
                                            LazyVGrid(columns: columns, spacing: 14) {
                                                ForEach(avatars) { item in
                                                    Button(action: { selectAvatar(item) }) {
                                                        VStack(spacing: 6) {
                                                            ZStack {
                                                                if let link = item.link, let url = URL(string: link) {
                                                                    AnimatedGIFView(url: url)
                                                                        .frame(width: 72, height: 72)
                                                                        .cornerRadius(12)
                                                                        .clipped()
                                                                } else {
                                                                    Rectangle()
                                                                        .fill(Color(hex: "1F1F24"))
                                                                        .frame(width: 72, height: 72)
                                                                        .cornerRadius(12)
                                                                }

                                                                if selectedAvatarId == item.id && isSetting {
                                                                    Color.black.opacity(0.6)
                                                                        .cornerRadius(12)
                                                                    ProgressView().tint(.white)
                                                                }
                                                            }
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(selectedAvatarId == item.id ? Color.red : Color.white.opacity(0.1), lineWidth: selectedAvatarId == item.id ? 2.5 : 1)
                                                            )

                                                            if let name = item.name, !name.isEmpty {
                                                                Text(name)
                                                                    .font(.system(size: 11, weight: .medium))
                                                                    .foregroundColor(.white.opacity(0.8))
                                                                    .lineLimit(1)
                                                                    .frame(width: 72)
                                                            }
                                                        }
                                                    }
                                                    .buttonStyle(ScaleButtonStyle())
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }

                                if hasNextPage && searchText.isEmpty {
                                    HStack {
                                        Spacer()
                                        ProgressView().tint(.red)
                                            .onAppear {
                                                loadNextPage()
                                            }
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Avatar Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                loadInitialAvatars()
            }
        }
    }

    private func loadInitialAvatars() {
        currentPage = 1
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let page = try await api.fetchAvatarList(page: 1, query: nil)
                await MainActor.run {
                    self.groups = page.data ?? []
                    self.hasNextPage = page.next_page != nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadNextPage() {
        guard !isLoading, hasNextPage else { return }
        currentPage += 1
        Task {
            do {
                let page = try await api.fetchAvatarList(page: currentPage, query: nil)
                await MainActor.run {
                    if let newGroups = page.data {
                        self.groups.append(contentsOf: newGroups)
                    }
                    self.hasNextPage = page.next_page != nil
                }
            } catch {
                await MainActor.run {
                    self.hasNextPage = false
                }
            }
        }
    }

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            loadInitialAvatars()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await MainActor.run { self.isLoading = true }
            do {
                let page = try await api.fetchAvatarList(page: 1, query: q)
                await MainActor.run {
                    self.groups = page.data ?? []
                    self.hasNextPage = false
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.groups = []
                    self.isLoading = false
                }
            }
        }
    }

    private func selectAvatar(_ item: AvatarItem) {
        guard let avatarSet = item.avatar_set, !isSetting else { return }
        selectedAvatarId = item.id
        isSetting = true

        Task {
            do {
                try await api.setProfileAvatar(id: profileId, avatarSet: avatarSet)
                await auth.fetchUserDetails()
                await MainActor.run {
                    self.isSetting = false
                    self.onAvatarSelected()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSetting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
