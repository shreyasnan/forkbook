import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Configuration

class FirebaseConfig {
    static let shared = FirebaseConfig()

    private(set) var db: Firestore!

    private init() {}

    func configure() {
        FirebaseApp.configure()
        db = Firestore.firestore()

        #if DEBUG
        // Use longer cache for development
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
        #endif
    }
}
