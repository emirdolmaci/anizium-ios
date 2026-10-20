import SwiftUI

public struct SettingsView: View {
    @AppStorage("auto_skip_intro") private var autoSkipIntro = true
    @AppStorage("auto_next_episode") private var autoNextEpisode = true
    @AppStorage("default_quality") private var defaultQuality = "1080p"

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                Form {
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
                            Text("iOS / iPadOS")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .listRowBackground(Color(hex: "1F1F24"))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
