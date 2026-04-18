import Foundation
import CoreLocation

// MARK: - Location Manager
// Lightweight CLLocationManager wrapper for "while using" location access.
// Used to sort restaurants by proximity on the Home screen.

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    // MARK: - Distance Helpers

    /// Distance in miles from user to a coordinate. Returns nil if no user location.
    func distanceMiles(to lat: Double, lng: Double) -> Double? {
        guard let userLocation else { return nil }
        let destination = CLLocation(latitude: lat, longitude: lng)
        let meters = userLocation.distance(from: destination)
        return meters / 1609.34
    }

    /// Format distance for display
    static func formatDistance(_ miles: Double) -> String {
        if miles < 0.1 { return "Nearby" }
        if miles < 1.0 { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }
}

// MARK: - Geocoding Helper
// Geocodes an address string to lat/lng. Uses CLGeocoder (rate-limited by Apple).

enum GeocodingHelper {
    private static let geocoder = CLGeocoder()

    /// Geocode an address to (latitude, longitude). Returns nil on failure.
    static func geocode(address: String) async -> (Double, Double)? {
        guard !address.isEmpty else { return nil }
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let location = placemarks.first?.location?.coordinate {
                return (location.latitude, location.longitude)
            }
        } catch {
            print("Geocoding failed for '\(address)': \(error.localizedDescription)")
        }
        return nil
    }
}
