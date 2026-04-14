import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var showOnboarding = false
    @State private var hasCheckedOnboarding = false

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
        TabView {
            HomeTestView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SearchTestView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            MyPlacesTestView()
                .tabItem {
                    Label("My Places", systemImage: "bookmark")
                }

            TableTestView()
                .tabItem {
                    Label("Table", systemImage: "person.2")
                }
        }
        .tint(Color.fbText)
        .fullScreenCover(isPresented: $showOnboarding) {
            InviteOnboardingView(
                onComplete: {
                    showOnboarding = false
                    Task {
                        try? await FirestoreService.shared.saveTastePreferences(
                            TastePreferences(onboardingCompleted: true)
                        )
                    }
                }
            )
        }
        .task {
            guard !hasCheckedOnboarding else { return }
            hasCheckedOnboarding = true

            // Sync Firestore entries into local store (one-time import)
            await store.importFromFirestore()

            // DEBUG: Always show onboarding (revert before shipping)
            showOnboarding = true
            // let prefs = await FirestoreService.shared.getTastePreferences()
            // if !prefs.onboardingCompleted {
            //     showOnboarding = true
            // }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
