import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var store: RestaurantStore
    // Onboarding disabled for now — re-enable when ready to ship.
    // @State private var showOnboarding = false
    // @State private var hasCheckedOnboarding = false

    // Tracks the currently selected tab. Exposed as a Binding to child views
    // that need to programmatically switch tabs — e.g. Search routes the user
    // back to Home after they log a meal.
    @State private var selectedTab: Int = 0

    init() {
        // Instagram-style dark tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.fbBg)
        tabBarAppearance.shadowColor = UIColor(Color.fbBorder)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Instagram-style dark navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.fbBg)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.fbText)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.fbText)]
        navAppearance.shadowColor = UIColor(Color.fbBorder)

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTestView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            SearchTestView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            MyPlacesTestView()
                .tabItem {
                    Label("My Places", systemImage: "bookmark")
                }
                .tag(2)

            TableTestView()
                .tabItem {
                    Label("Table", systemImage: "person.2")
                }
                .tag(3)
        }
        .tint(Color.fbText)
    }
}

#Preview {
    ContentView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
