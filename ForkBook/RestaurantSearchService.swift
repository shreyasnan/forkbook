import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - Restaurant Search using MKLocalSearch
//
// Moved from MKLocalSearchCompleter → MKLocalSearch because the
// completer's `region` is only a soft bias: MapKit still surfaces
// "famous name" matches from anywhere (Edmonton, Newark DE, etc.)
// for ambiguous queries. MKLocalSearch returns MKMapItems with full
// placemark coordinates, so we can HARD-filter by actual distance
// from the user.
//
// Flow per keystroke:
//   1. Debounce 300ms on searchText.
//   2. Cancel any in-flight MKLocalSearch.
//   3. Fire a new MKLocalSearch biased to the user's region.
//   4. Drop any result >75 miles from the user (hard distance cap).
//   5. Dedupe by (name, formatted-subtitle) — MKLocalSearch often
//      returns the same POI multiple times.
//   6. Publish up to 8 suggestions.

class RestaurantSearchService: NSObject, ObservableObject {
    @Published var searchText: String = ""
    @Published var suggestions: [RestaurantSuggestion] = []
    @Published var isSearching: Bool = false

    private var textSubscription: AnyCancellable?
    private var locationSubscription: AnyCancellable?
    private var currentSearch: MKLocalSearch?

    /// The center used for search region bias + distance filtering.
    /// Falls back to Bay Area (≈ SF Civic Center) until the user's
    /// real location arrives.
    private var searchCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
        latitude: 37.7749, longitude: -122.4194
    )

    /// Hard distance cap. Anything farther than this from `searchCenter`
    /// is dropped — this is what actually keeps Edmonton / Newark DE
    /// out of the results. 75mi is generous enough to cover "my metro"
    /// from any reasonable user position within the Bay Area.
    private static let maxDistanceMeters: CLLocationDistance = 75 * 1609.34

    /// Region hint passed to MKLocalSearch as a bias. Slightly smaller
    /// than the hard cap so MapKit ranks nearby matches first; the
    /// cap then catches anything that slips through.
    private static let regionSpanMeters: CLLocationDistance = 50 * 1609.34

    struct RestaurantSuggestion: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let subtitle: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    override init() {
        super.init()

        // Track user location → update searchCenter. Deliberately
        // simple chain; longer Combine chains trip Swift's type-check
        // budget.
        locationSubscription = LocationManager.shared.$userLocation
            .sink { [weak self] loc in
                guard let coord = loc?.coordinate else { return }
                self?.searchCenter = coord
            }

        // Debounce then fire search. 500ms trades a bit of responsiveness
        // for far fewer wasted MKLocalSearch round-trips while the user
        // is still typing — each call is ~400ms, so firing on every
        // 300ms gap meant rapid typing spawned 3-4 overlapping searches
        // before the first returned, and the UI felt sluggish.
        textSubscription = $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                if trimmed.count >= 2 {
                    self.startSearch(query: trimmed)
                } else {
                    self.currentSearch?.cancel()
                    self.suggestions = []
                    self.isSearching = false
                }
            }
    }

    func clear() {
        searchText = ""
        suggestions = []
        isSearching = false
        currentSearch?.cancel()
        currentSearch = nil
    }

    // MARK: Search

    private func startSearch(query: String) {
        currentSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        if #available(iOS 16.0, *) {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
                .restaurant, .cafe, .bakery, .brewery, .foodMarket
            ])
        }
        request.region = MKCoordinateRegion(
            center: searchCenter,
            latitudinalMeters: Self.regionSpanMeters,
            longitudinalMeters: Self.regionSpanMeters
        )

        isSearching = true
        let search = MKLocalSearch(request: request)
        currentSearch = search

        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSearching = false
                if let error {
                    print("Search error: \(error.localizedDescription)")
                    self.suggestions = []
                    return
                }
                guard let items = response?.mapItems else {
                    self.suggestions = []
                    return
                }
                self.suggestions = self.filterAndRank(items)
            }
        }
    }

    /// Drop far-away results, dedupe, cap at 8. Ranked by distance
    /// ascending so the closest candidates are always on top.
    private func filterAndRank(_ items: [MKMapItem]) -> [RestaurantSuggestion] {
        let userLoc = CLLocation(
            latitude: searchCenter.latitude,
            longitude: searchCenter.longitude
        )

        struct Scored {
            let item: MKMapItem
            let distance: CLLocationDistance
        }

        let within: [Scored] = items.compactMap { item in
            let coord = item.placemark.coordinate
            // Protect against (0,0) placemarks that MapKit sometimes
            // returns for unresolvable items.
            guard coord.latitude != 0 || coord.longitude != 0 else { return nil }
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let d = userLoc.distance(from: loc)
            guard d <= Self.maxDistanceMeters else { return nil }
            return Scored(item: item, distance: d)
        }
        .sorted { $0.distance < $1.distance }

        var seen: Set<String> = []
        var out: [RestaurantSuggestion] = []
        for s in within {
            let name = Self.bestName(for: s.item)
            let subtitle = Self.formatSubtitle(s.item.placemark)
            let key = "\(name.lowercased())|\(subtitle.lowercased())"
            if name.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            out.append(RestaurantSuggestion(name: name, subtitle: subtitle))
            if out.count >= 8 { break }
        }
        return out
    }

    /// Prefer whichever of `MKMapItem.name` vs `placemark.name` is
    /// longer/more descriptive — Apple's POI data sometimes stores
    /// the abbreviated brand on one and the full registered business
    /// name ("Khazana by Chef Sanjeev Kapoor") on the other.
    private static func bestName(for item: MKMapItem) -> String {
        let a = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
        let b = item.placemark.name?.trimmingCharacters(in: .whitespaces) ?? ""
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        // Only prefer b if it's clearly richer (longer AND contains a) —
        // otherwise the placemark often holds a plain address which
        // would wipe the real business name.
        if b.count > a.count && b.localizedCaseInsensitiveContains(a) {
            return b
        }
        return a
    }

    /// Format a readable subtitle from placemark components. Prefers
    /// "Street, City" over raw MKMapItem strings that sometimes only
    /// contain a unit number or zip code.
    private static func formatSubtitle(_ placemark: MKPlacemark) -> String {
        var parts: [String] = []
        if let addr = placemark.thoroughfare {
            if let num = placemark.subThoroughfare {
                parts.append("\(num) \(addr)")
            } else {
                parts.append(addr)
            }
        }
        if let city = placemark.locality {
            parts.append(city)
        } else if let area = placemark.subAdministrativeArea {
            parts.append(area)
        }
        return parts.joined(separator: ", ")
    }
}
