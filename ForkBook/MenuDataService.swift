import Foundation

// MARK: - MenuDataService
//
// Fetches restaurant menus from Cloud Storage, keyed by Google Place ID.
//
// Why Cloud Storage and not Firestore:
// - Menus are write-rarely, read-never-changing blobs that don't need
//   Firestore's indexing or real-time listeners.
// - Storage reads are ~10x cheaper per GB and have no per-document limit
//   to worry about — a 200-dish menu is comfortably under the 1MB doc cap
//   but could hit it with images/tags/translations later.
// - Public-read JSON + plain URLSession keeps us off the Firebase Storage
//   SDK (no SPM churn), which matters because we don't upload from the
//   app — only download.
//
// Lookup key: Google Place ID, set by PlacesResolver on add/update.
// If a restaurant has no placeId (resolution pending or failed), lookups
// return empty — by design. The app's UI surfaces "menu loading" until
// the placeId arrives (usually within 1–2 seconds of adding).
//
// Caching:
//   Tier 1 (memory)  — [placeId: CacheEntry], session-scoped, fast.
//                      Holds both hits and confirmed misses (404s).
//   Tier 2 (disk)    — JSON files in Caches/menus/{placeId}.json.
//                      Survives restart. iOS may purge if storage is low.
//                      Hits only — negatives aren't persisted.
//   Inflight dedupe  — concurrent calls for the same placeId share one
//                      network request.
//
// Freshness (stale-while-revalidate):
//   Disk cache is served IMMEDIATELY regardless of age (snappy UX),
//   then if the cached file is older than `diskCacheTTL` (6h), a
//   background re-fetch updates the cache for the next call. Result:
//   users see a menu within a day of the daily scraper run, without
//   ever waiting on the network when there's something cached.

@MainActor
final class MenuDataService: ObservableObject {
    static let shared = MenuDataService()

    // MARK: Config
    //
    // Bucket matches `STORAGE_BUCKET` in GoogleService-Info.plist. Files live
    // at  gs://forkbook-fe65b.firebasestorage.app/menus/{placeId}.json
    // and are fetched over HTTPS via the Firebase download endpoint:
    //   https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded-path}?alt=media
    // `alt=media` returns the raw file body instead of a metadata JSON wrapper.
    private let storageBucket = "forkbook-fe65b.firebasestorage.app"

    /// Schema version the client understands. Bump in lockstep with the
    /// scraper's writer if the JSON shape changes.
    static let schemaVersion = 1

    /// How long a disk-cached menu is considered fresh. Older than this
    /// triggers a background refresh on next access (stale-while-
    /// revalidate). The daily scraper runs at 5 AM Pacific, so 6h
    /// guarantees that within ~half a day of any push, users see fresh
    /// data — without ever blocking the UI on the network.
    private static let diskCacheTTL: TimeInterval = 6 * 60 * 60

    // MARK: - Dish-name noise filter
    //
    // The scraper occasionally pulls section headers ("WONTONS", "GREENS")
    // and description prose ("A light and delicious steamed beef broth
    // with tender slices...") into menu_items.name. These look terrible as
    // dish chips. Keep this filter in sync with `is_dishlike()` in
    // push_menus_to_storage.py — the push script runs the same checks
    // server-side, but we filter here too so older uploads don't leak.

    /// Real dish names rarely exceed this; "Sticky Rice Shao Mai with
    /// Kurobuta Pork & Mushroom" is ~50 chars.
    private static let maxDishNameLen = 60

    private static let descriptionPrefixes: [String] = [
        "a light ", "a rich ", "a warm ", "a fresh ", "a delicate ",
        "our signature ", "our famous ", "our classic ",
        "made with ", "served with ", "topped with ", "featuring ",
        "crafted with ", "prepared with ",
    ]

    private static let sectionHeaderWords: Set<String> = [
        "wontons", "greens", "appetizers", "starters", "sides", "salads",
        "soups", "desserts", "drinks", "beverages", "beers", "wines", "cocktails",
        "mains", "entrees", "entrées", "noodles", "rice", "dumplings", "specials",
        "breakfast", "lunch", "dinner", "brunch", "kids menu", "for the table",
    ]

    static func isDishlike(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.count <= maxDishNameLen else { return false }
        // Section header: short ALL-CAPS matching a known header word.
        if s == s.uppercased(), sectionHeaderWords.contains(s.lowercased()) {
            return false
        }
        // Description prose: starts with a known prose marker.
        let low = s.lowercased()
        for prefix in descriptionPrefixes where low.hasPrefix(prefix) {
            return false
        }
        // 3+ commas strongly suggests a descriptive sentence.
        if s.filter({ $0 == "," }).count >= 3 { return false }
        return true
    }

    // MARK: State

    enum CacheEntry {
        case hit(MenuRestaurant)
        case miss  // confirmed absent (404) — don't re-fetch this session
    }

    private var memory: [String: CacheEntry] = [:]
    private var inflight: [String: Task<MenuRestaurant?, Never>] = [:]
    private let session: URLSession
    private let diskDir: URL?

    private init(session: URLSession = .shared) {
        self.session = session

        // Caches directory — iOS may purge under storage pressure, which is
        // exactly the semantics we want for menu data.
        if let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first {
            let dir = caches.appendingPathComponent("menus", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
            self.diskDir = dir
        } else {
            self.diskDir = nil
        }
    }

    // MARK: - Public API (async)

    /// Returns the full menu for a placeId, or nil if none exists.
    func menu(forPlaceId placeId: String) async -> MenuRestaurant? {
        let key = placeId.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        // 1) Memory
        if let entry = memory[key] {
            switch entry {
            case .hit(let m): return m
            case .miss: return nil
            }
        }

        // 2) Inflight request dedupe — if another caller is already fetching
        //    this placeId, await their result instead of racing.
        if let running = inflight[key] {
            return await running.value
        }

        // 3) Disk, then network
        let task = Task<MenuRestaurant?, Never> { [weak self] in
            guard let self else { return nil }
            if let fromDisk = self.loadFromDisk(placeId: key) {
                self.memory[key] = .hit(fromDisk)
                // Stale-while-revalidate: serve cached immediately, but
                // if the disk file is older than the TTL, fire a
                // background refresh so the next call gets fresher data.
                if self.isDiskCacheStale(placeId: key) {
                    self.scheduleBackgroundRefresh(placeId: key)
                }
                return fromDisk
            }
            let result = await self.fetch(placeId: key)
            // Record result in memory either way.
            if let result {
                self.memory[key] = .hit(result)
                self.saveToDisk(result, placeId: key)
            } else {
                self.memory[key] = .miss
            }
            return result
        }
        inflight[key] = task
        let out = await task.value
        inflight[key] = nil
        return out
    }

    /// True if the disk file for this placeId exists and was last
    /// written more than `diskCacheTTL` ago. Returns false if the file
    /// is missing or its mtime can't be read.
    private func isDiskCacheStale(placeId: String) -> Bool {
        guard let url = diskURL(for: placeId),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modDate) > Self.diskCacheTTL
    }

    /// Fire-and-forget refresh of a placeId's menu. Updates memory +
    /// disk if the fetch succeeds; silently ignores failures (the
    /// stale cached copy stays valid until the next attempt).
    private func scheduleBackgroundRefresh(placeId: String) {
        // Don't double-schedule if a refresh is already running.
        guard inflight[placeId] == nil else { return }
        let refreshTask = Task<MenuRestaurant?, Never> { [weak self] in
            guard let self else { return nil }
            let fresh = await self.fetch(placeId: placeId)
            if let fresh {
                self.memory[placeId] = .hit(fresh)
                self.saveToDisk(fresh, placeId: placeId)
            }
            return fresh
        }
        inflight[placeId] = refreshTask
        // Detach the cleanup so we don't await on the calling path.
        Task { [weak self] in
            _ = await refreshTask.value
            self?.inflight[placeId] = nil
        }
    }

    /// Dishes list for a placeId, or empty.
    func dishes(forPlaceId placeId: String) async -> [MenuDish] {
        await menu(forPlaceId: placeId)?.dishes ?? []
    }

    /// Top N dishes (already ordered by the scraper — price descending).
    func topDishes(forPlaceId placeId: String, limit: Int = 8) async -> [MenuDish] {
        Array(await dishes(forPlaceId: placeId).prefix(limit))
    }

    /// Dish names only — handy for the "I went here" checklist.
    func dishNames(forPlaceId placeId: String, limit: Int = 15) async -> [String] {
        await topDishes(forPlaceId: placeId, limit: limit).map(\.name)
    }

    // MARK: - Public API (sync — cache-only)
    //
    // Use these for UI decisions that shouldn't block on network (e.g.
    // "should I show a menu chevron on this row right now?"). If the
    // answer is no, kick off an async prefetch and let SwiftUI re-render
    // when the @Published store changes.

    func cachedMenu(forPlaceId placeId: String) -> MenuRestaurant? {
        if case let .hit(m) = memory[placeId] { return m }
        return nil
    }

    func cachedDishes(forPlaceId placeId: String) -> [MenuDish] {
        cachedMenu(forPlaceId: placeId)?.dishes ?? []
    }

    func hasCachedMenu(forPlaceId placeId: String) -> Bool {
        if case .hit = memory[placeId] { return true }
        return false
    }

    /// Fire-and-forget prefetch. Use when a placeId becomes visible in the
    /// UI but doesn't need its menu immediately — e.g. scrolling past a row.
    func prefetch(placeId: String) {
        guard !placeId.isEmpty, memory[placeId] == nil, inflight[placeId] == nil else {
            return
        }
        Task { _ = await self.menu(forPlaceId: placeId) }
    }

    // MARK: - Invalidation

    /// Drop cached entry for a placeId (memory + disk). Useful after a
    /// known menu refresh on the backend, or during debugging.
    func invalidate(placeId: String) {
        memory[placeId] = nil
        if let diskDir {
            let file = diskDir.appendingPathComponent("\(placeId).json")
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Network

    private func fetch(placeId: String) async -> MenuRestaurant? {
        guard let url = downloadURL(forPlaceId: placeId) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode == 404 {
                print("[MenuDataService] 404 for placeId=\(placeId) — menu not in Storage")
                return nil  // legitimate miss
            }
            guard http.statusCode == 200 else {
                print("[MenuDataService] HTTP \(http.statusCode) for placeId=\(placeId)")
                return nil
            }
            return try parse(data: data, placeId: placeId)
        } catch {
            print("[MenuDataService] fetch failed for placeId=\(placeId): \(error)")
            return nil
        }
    }

    private func downloadURL(forPlaceId placeId: String) -> URL? {
        // Firebase Storage paths are percent-encoded like query params — the
        // `/` between `menus` and the file becomes `%2F`. `alt=media` returns
        // the raw body rather than the metadata wrapper.
        let path = "menus/\(placeId).json"
        let encodedPath = path.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        ) ?? path
        return URL(
            string: "https://firebasestorage.googleapis.com/v0/b/\(storageBucket)/o/\(encodedPath)?alt=media"
        )
    }

    private func parse(data: Data, placeId: String) throws -> MenuRestaurant? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MenuFileV1.self, from: data)
        if decoded.v != Self.schemaVersion {
            print(
                "[MenuDataService] schema mismatch for \(placeId): "
                + "file v=\(decoded.v) client v=\(Self.schemaVersion)"
            )
            // Don't hard-fail on a minor bump — try the v1 shape anyway.
            // If the scraper ships a real breaking change, bump both sides.
        }
        let dishes = decoded.dishes.compactMap { d -> MenuDish? in
            guard let name = d.n, !name.isEmpty else { return nil }
            // Belt-and-suspenders filter for scraper noise. The push
            // script also filters, but (a) older uploads in Storage
            // predate that filter and (b) disk caches from this client
            // may still hold junk. Kept in sync with is_dishlike() in
            // push_menus_to_storage.py — if you change one, change both.
            guard Self.isDishlike(name) else { return nil }
            return MenuDish(name: name, description: d.d, price: d.p ?? 0)
        }
        return MenuRestaurant(
            placeId: placeId,
            name: decoded.name ?? "",
            cuisine: decoded.cuisine ?? "",
            city: decoded.city ?? "",
            dishes: dishes,
            scrapedAt: decoded.scrapedAt,
            source: decoded.source
        )
    }

    // MARK: - Disk cache

    private func diskURL(for placeId: String) -> URL? {
        diskDir?.appendingPathComponent("\(placeId).json")
    }

    private func loadFromDisk(placeId: String) -> MenuRestaurant? {
        guard let url = diskURL(for: placeId),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? parse(data: data, placeId: placeId)) ?? nil
    }

    private func saveToDisk(_ menu: MenuRestaurant, placeId: String) {
        // Re-encode from the parsed model rather than saving raw bytes —
        // one code path for parse/encode, and a schema bump invalidates
        // older files naturally via the `v` check.
        guard let url = diskURL(for: placeId) else { return }
        let file = DiskMenuV1(
            v: Self.schemaVersion,
            name: menu.name,
            cuisine: menu.cuisine.isEmpty ? nil : menu.cuisine,
            city: menu.city.isEmpty ? nil : menu.city,
            dishes: menu.dishes.map { DishV1(n: $0.name, d: $0.description, p: $0.price) },
            scrapedAt: menu.scrapedAt,
            source: menu.source
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Wire format (schema v1)
//
// This struct IS the contract between the Python scraper's upload
// step and the iOS reader. Changes here require bumping
// `MenuDataService.schemaVersion` and updating the writer.

private struct MenuFileV1: Decodable {
    let v: Int
    let name: String?
    let cuisine: String?
    let city: String?
    let dishes: [DishV1]
    let scrapedAt: Date?
    let source: String?
}

private struct DiskMenuV1: Codable {
    let v: Int
    let name: String?
    let cuisine: String?
    let city: String?
    let dishes: [DishV1]
    let scrapedAt: Date?
    let source: String?
}

private struct DishV1: Codable {
    /// Name. Compact key to keep payloads small on cellular.
    let n: String?
    /// Description.
    let d: String?
    /// Price in the restaurant's local currency (assumed USD for now).
    let p: Double?
}

// MARK: - Models

struct MenuDish: Equatable {
    let name: String
    let description: String?
    let price: Double
}

struct MenuRestaurant: Equatable {
    let placeId: String
    let name: String
    let cuisine: String
    let city: String
    let dishes: [MenuDish]
    let scrapedAt: Date?
    let source: String?
}
