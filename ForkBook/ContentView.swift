import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var store: RestaurantStore

    /// Onboarding gate. Three-state machine:
    ///   - `nil` while we're asking Firestore if the user has finished
    ///     onboarding before. Renders LaunchScreenView so the empty
    ///     TabView never flashes.
    ///   - `true`  → show TasteOnboardingView until completion.
    ///   - `false` → show the main TabView.
    /// `TasteOnboardingView` writes `onboardingCompleted=true` to
    /// Firestore on its own when the user finishes, so we just need
    /// to flip this state when its onComplete fires.
    @State private var needsOnboarding: Bool? = nil

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
        Group {
            switch needsOnboarding {
            case nil:
                // Brief loading window while we ask Firestore if this
                // user has onboarded before. Hides the tab-flash that
                // would otherwise happen.
                LaunchScreenView()
            case .some(true):
                TasteOnboardingView {
                    // TasteOnboardingView already wrote onboardingCompleted=true
                    // to Firestore inside its own save flow; we just dismiss.
                    needsOnboarding = false
                }
            case .some(false):
                mainTabView
            }
        }
        .task {
            // Only check once per ContentView appearance. AuthService
            // controls when ContentView is shown vs SignInView, so by
            // the time we get here the user is signed in.
            let prefs = await FirestoreService.shared.getTastePreferences()
            needsOnboarding = !prefs.onboardingCompleted
        }
    }

    private var mainTabView: some View {
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

            MyPlacesTestView(selectedTab: $selectedTab)
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
