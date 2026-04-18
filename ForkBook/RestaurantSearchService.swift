import Foundation
import MapKit
import Combine

// MARK: - Restaurant Autocomplete using MapKit

class RestaurantSearchService: NSObject, ObservableObject {
    @Published var searchText: String = ""
    @Published var suggestions: [RestaurantSuggestion] = []
    @Published var isSearching: Bool = false

    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?

    struct RestaurantSuggestion: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let subtitle: String // address or area

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()

        completer.delegate = self

        // Restaurant-only: use .pointOfInterest and filter to food categories
        completer.resultTypes = .pointOfInterest

        // Filter to restaurant-related categories
        if #available(iOS 16.0, *) {
            completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [
                .restaurant,
                .cafe,
                .bakery,
                .brewery,
                .foodMarket
            ])
        }

        // Debounce search text so we don't fire on every keystroke
        cancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                if trimmed.count >= 2 {
                    self.isSearching = true
                    self.completer.queryFragment = trimmed
                } else {
                    self.suggestions = []
                    self.isSearching = false
                }
            }
    }

    func clear() {
        searchText = ""
        suggestions = []
        isSearching = false
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension RestaurantSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.suggestions = completer.results.prefix(8).map { result in
                RestaurantSuggestion(
                    name: result.title,
                    subtitle: result.subtitle
                )
            }
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
            print("Search completer error: \(error.localizedDescription)")
        }
    }
}
