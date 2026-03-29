import SwiftUI

struct ContentView: View {
    init() {
        // Instagram-style dark tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.igBlack)

        // Divider line at top of tab bar
        tabBarAppearance.shadowColor = UIColor(Color.igDivider)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Instagram-style dark navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.igBlack)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.igTextPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.igTextPrimary)]
        navAppearance.shadowColor = UIColor(Color.igDivider)

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView {
            VisitedListView()
                .tabItem {
                    Label("My Restaurants", systemImage: "fork.knife")
                }

            WishlistView()
                .tabItem {
                    Label("Wishlist", systemImage: "star.bubble")
                }
        }
        .tint(Color.igTextPrimary)
    }
}

#Preview {
    ContentView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
