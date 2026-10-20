import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0

    public init() {
        // Dark translucent tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "121216"))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Ana Sayfa")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Keşfet")
                }
                .tag(1)

            WatchlistView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "bookmark.fill" : "bookmark")
                    Text("Listem")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                    Text("Ayarlar")
                }
                .tag(3)
        }
        .tint(.red)
        .preferredColorScheme(.dark)
    }
}
