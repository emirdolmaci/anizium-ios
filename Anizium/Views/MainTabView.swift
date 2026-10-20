import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0

    public init() {
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

            CalendarView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "calendar.badge.clock" : "calendar")
                    Text("Takvim")
                }
                .tag(2)

            WatchlistView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "bookmark.fill" : "bookmark")
                    Text("Listem")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    Text("Ayarlar")
                }
                .tag(4)
        }
        .tint(.red)
        .preferredColorScheme(.dark)
    }
}
