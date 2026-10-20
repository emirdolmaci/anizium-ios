import SwiftUI

public struct SettingsView: View {
    @StateObject private var auth = AuthManager.shared
    @AppStorage("auto_skip_intro") private var autoSkipIntro = true
    @AppStorage("auto_next_episode") private var autoNextEpisode = true
    @AppStorage("default_quality") private var defaultQuality = "1080p"

    @State private var showLoginSheet = false
    @State private var showLogoutConfirm = false
    @State private var cacheCleared = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                Form {
                    // MARK: - Account Section
                    Section(header: Text("HESAP").foregroundColor(.white.opacity(0.5))) {
                        if auth.isLoggedIn {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Text(String((auth.activeProfile?.name ?? auth.currentUser?.nick ?? "U").prefix(1)).uppercased())
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(auth.activeProfile?.name ?? auth.currentUser?.nick ?? "Kullanıcı")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)

                                        if auth.currentUser?.premium == true {
                                            Text("PREMIUM")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundColor(.yellow)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.yellow.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }

                                    if let email = auth.currentUser?.email, !email.isEmpty {
                                        Text(email)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            // Profile switcher if multiple
                            if let profiles = auth.currentUser?.profiles, profiles.count > 1 {
                                Picker("Aktif Profil", selection: Binding(
                                    get: { auth.activeProfile ?? profiles[0] },
                                    set: { auth.selectProfile($0) }
                                )) {
                                    ForEach(profiles) { p in
                                        Text(p.name ?? "Profil").tag(p)
                                    }
                                }
                            }

                            Button(role: .destructive, action: {
                                showLogoutConfirm = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Çıkış Yap")
                                }
                                .foregroundColor(.red)
                            }
                        } else {
                            Button(action: {
                                showLoginSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Giriş Yap / Kayıt Ol")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Yorum yapmak ve favorilerini senkronize etmek için hesabına bağlan.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "1F1F24"))

                    // MARK: - Playback Settings
                    Section(header: Text("OYNATMA AYARLARI").foregroundColor(.white.opacity(0.5))) {
                        Toggle("İntroyu Otomatik Atla", isOn: $autoSkipIntro)
                            .tint(.red)
                        Toggle("Sonraki Bölümü Otomatik Oynat", isOn: $autoNextEpisode)
                            .tint(.red)

                        Picker("Varsayılan Çözünürlük", selection: $defaultQuality) {
                            Text("1080p (FHD)").tag("1080p")
                            Text("720p (HD)").tag("720p")
                            Text("480p (SD)").tag("480p")
                        }
                    }
                    .listRowBackground(Color(hex: "1F1F24"))

                    // MARK: - Storage & Cache
                    Section(header: Text("DEPOLAMA VE ÖNBELLEK").foregroundColor(.white.opacity(0.5))) {
                        Button(action: clearCache) {
                            HStack {
                                Text(cacheCleared ? "Önbellek Temizlendi" : "Görsel Önbelleğini Temizle")
                                    .foregroundColor(cacheCleared ? .green : .white)
                                Spacer()
                                Image(systemName: cacheCleared ? "checkmark" : "trash")
                                    .foregroundColor(cacheCleared ? .green : .white.opacity(0.5))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "1F1F24"))

                    // MARK: - About
                    Section(header: Text("HAKKINDA").foregroundColor(.white.opacity(0.5))) {
                        HStack {
                            Text("Uygulama")
                            Spacer()
                            Text("Anizium iOS")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        HStack {
                            Text("Sürüm")
                            Spacer()
                            Text("2.1.0")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        HStack {
                            Text("Platform")
                            Spacer()
                            Text("iOS / iPadOS Native")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .listRowBackground(Color(hex: "1F1F24"))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLoginSheet) {
                LoginSheetView()
            }
            .alert("Çıkış Yapılsın mı?", isPresented: $showLogoutConfirm) {
                Button("Çıkış Yap", role: .destructive) {
                    auth.logout()
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?")
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheCleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            cacheCleared = false
        }
    }
}
