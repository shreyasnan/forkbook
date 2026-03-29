import SwiftUI

@main
struct ForkBookApp: App {
    @StateObject private var store = RestaurantStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
