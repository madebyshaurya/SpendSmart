import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - GeocodingService
/// Caches address → coordinate lookups using MapKit geocoding with legacy fallback

@MainActor
class GeocodingService: ObservableObject {
    static let shared = GeocodingService()
    
    // MARK: - Published Properties
    @Published private(set) var isGeocoding = false
    @Published private(set) var geocodedLocations: [String: StoreLocation] = [:]
    
    // MARK: - Private Properties
    private let cache = GeocodingCache()
    private var pendingRequests: [String: Task<StoreLocation?, Never>] = [:]
    
    // Rate limiting (Apple allows ~50 requests per minute)
    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    private init() {
        // Load cached locations on init
        geocodedLocations = cache.loadAll()
    }
    
    // MARK: - Public Methods
    
    /// Geocode a single address, returning cached result if available
    func geocode(address: String) async -> StoreLocation? {
        let normalizedAddress = normalizeAddress(address)
        
        // Check memory cache first
        if let cached = geocodedLocations[normalizedAddress] {
            return cached
        }
        
        // Check if there's already a pending request for this address
        if let pendingTask = pendingRequests[normalizedAddress] {
            return await pendingTask.value
        }
        
        // Create new geocoding task
        let task = Task<StoreLocation?, Never> {
            await performGeocode(address: normalizedAddress, originalAddress: address)
        }
        
        pendingRequests[normalizedAddress] = task
        let result = await task.value
        pendingRequests.removeValue(forKey: normalizedAddress)
        
        return result
    }
    
    /// Batch geocode multiple addresses (for initial map load)
    func geocodeBatch(addresses: [String]) async -> [String: StoreLocation] {
        var results: [String: StoreLocation] = [:]
        
        // First, collect all addresses that need geocoding
        var toGeocode: [String] = []
        for address in addresses {
            let normalized = normalizeAddress(address)
            if let cached = geocodedLocations[normalized] {
                results[address] = cached
            } else if !normalized.isEmpty {
                toGeocode.append(address)
            }
        }
        
        // Geocode remaining addresses with rate limiting
        for address in toGeocode {
            if let location = await geocode(address: address) {
                results[address] = location
            }
            // Small delay between requests to respect rate limits
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        }
        
        return results
    }
    
    /// Geocode all stores from receipts
    func geocodeStores(from receipts: [Receipt]) async -> [StoreLocation] {
        // Group receipts by store address to avoid duplicates
        var storesByAddress: [String: [Receipt]] = [:]
        for receipt in receipts {
            let address = receipt.store_address
            guard !address.isEmpty else { continue }
            storesByAddress[address, default: []].append(receipt)
        }
        
        var locations: [StoreLocation] = []
        
        for (address, storeReceipts) in storesByAddress {
            if let location = await geocode(address: address) {
                // Enrich with receipt data
                var enrichedLocation = location
                enrichedLocation.receipts = storeReceipts
                enrichedLocation.storeName = storeReceipts.first?.store_name ?? location.storeName
                enrichedLocation.totalSpent = storeReceipts.reduce(0) { $0 + $1.total_amount }
                enrichedLocation.visitCount = storeReceipts.count
                locations.append(enrichedLocation)
            }
        }
        
        return locations
    }
    
    /// Clear all cached data
    func clearCache() {
        geocodedLocations.removeAll()
        cache.clearAll()
    }
    
    /// Get region that encompasses all locations
    func regionForLocations(_ locations: [StoreLocation]) -> MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }
        
        let coordinates = locations.map { $0.coordinate }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add some padding
        let latDelta = (maxLat - minLat) * 1.5 + 0.01
        let lonDelta = (maxLon - minLon) * 1.5 + 0.01
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    // MARK: - Private Methods
    
    private func performGeocode(address: String, originalAddress: String) async -> StoreLocation? {
        // Rate limiting
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minRequestInterval {
            let delay = UInt64((minRequestInterval - timeSinceLastRequest) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
        
        lastRequestTime = Date()
        isGeocoding = true
        defer { isGeocoding = false }
        
        do {
            guard #available(iOS 26.0, *) else {
                // Fallback: use CLGeocoder for iOS < 26
                return await fallbackGeocode(address: originalAddress)
            }
            let storeLocation = try await mapKitGeocode(address: address, originalAddress: originalAddress)

            guard let storeLocation = storeLocation else {
                print("📍 [Geocoding] No results for: \(originalAddress)")
                return nil
            }

            // Cache result
            geocodedLocations[address] = storeLocation
            cache.save(storeLocation, for: address)

            print("📍 [Geocoding] Success: \(originalAddress) → \(storeLocation.coordinate)")
            return storeLocation
        } catch {
            print("📍 [Geocoding] Error for '\(originalAddress)': \(error.localizedDescription)")
            return nil
        }
    }

    @available(iOS 26.0, *)
    private func mapKitGeocode(address: String, originalAddress: String) async throws -> StoreLocation? {
        guard let request = MKGeocodingRequest(addressString: originalAddress) else { return nil }
        let mapItems = try await fetchMapItems(from: request)
        guard let mapItem = mapItems?.first else { return nil }

        let representations = mapItem.addressRepresentations
        let (city, state) = cityState(from: representations)

        return StoreLocation(
            id: UUID(),
            address: originalAddress,
            coordinate: mapItem.location.coordinate,
            storeName: mapItem.name ?? "",
            city: city,
            state: state,
            country: representations?.regionName,
            postalCode: nil
        )
    }

    @available(iOS 26.0, *)
    private func fetchMapItems(from request: MKGeocodingRequest) async throws -> [MKMapItem]? {
        try await withCheckedThrowingContinuation { continuation in
            request.getMapItems { mapItems, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: mapItems)
            }
        }
    }

    @available(iOS 26.0, *)
    private func cityState(from representations: MKAddressRepresentations?) -> (city: String?, state: String?) {
        guard let representations = representations else { return (nil, nil) }
        var city = representations.cityName
        var state: String? = nil

        if let context = representations.cityWithContext(.short) {
            let parts = context
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let first = parts.first, city == nil {
                city = String(first)
            }
            if parts.count >= 2 {
                state = String(parts[1])
            }
        }

        return (city, state)
    }

    
    private func fallbackGeocode(address: String) async -> StoreLocation? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let placemark = placemarks.first, let location = placemark.location else { return nil }
            return StoreLocation(
                id: UUID(),
                address: address,
                coordinate: location.coordinate,
                storeName: "",
                city: placemark.locality,
                state: placemark.administrativeArea,
                country: placemark.country,
                postalCode: placemark.postalCode
            )
        } catch {
            print("📍 [Geocoding] CLGeocoder fallback failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func normalizeAddress(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")
    }
}

// MARK: - StoreLocation Model

struct StoreLocation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let address: String
    let coordinate: CLLocationCoordinate2D
    var storeName: String
    var city: String?
    var state: String?
    var country: String?
    var postalCode: String?
    
    // Enriched data (not persisted)
    var receipts: [Receipt] = []
    var totalSpent: Double = 0
    var visitCount: Int = 0
    
    // Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, address, latitude, longitude, storeName, city, state, country, postalCode
    }
    
    init(id: UUID, address: String, coordinate: CLLocationCoordinate2D, storeName: String,
         city: String? = nil, state: String? = nil, country: String? = nil, postalCode: String? = nil) {
        self.id = id
        self.address = address
        self.coordinate = coordinate
        self.storeName = storeName
        self.city = city
        self.state = state
        self.country = country
        self.postalCode = postalCode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        address = try container.decode(String.self, forKey: .address)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        storeName = try container.decode(String.self, forKey: .storeName)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(address, forKey: .address)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(storeName, forKey: .storeName)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(postalCode, forKey: .postalCode)
    }
    
    static func == (lhs: StoreLocation, rhs: StoreLocation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Formatted address components
    var formattedCityState: String {
        [city, state].compactMap { $0 }.joined(separator: ", ")
    }
    
    var shortAddress: String {
        if let city = city {
            return city
        }
        // Return first line of address
        return address.components(separatedBy: ",").first ?? address
    }
}

// MARK: - Geocoding Cache (Persistent)

private class GeocodingCache {
    private let cacheKey = "geocoding_cache_v1"
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    struct CachedLocation: Codable {
        let location: StoreLocation
        let cachedAt: Date
    }
    
    func save(_ location: StoreLocation, for address: String) {
        var allCached = loadAllCached()
        allCached[address] = CachedLocation(location: location, cachedAt: Date())
        
        if let data = try? JSONEncoder().encode(allCached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    func loadAll() -> [String: StoreLocation] {
        let allCached = loadAllCached()
        let now = Date()
        
        var validLocations: [String: StoreLocation] = [:]
        for (address, cached) in allCached {
            // Only return non-expired entries
            if now.timeIntervalSince(cached.cachedAt) < maxCacheAge {
                validLocations[address] = cached.location
            }
        }
        
        return validLocations
    }
    
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    private func loadAllCached() -> [String: CachedLocation] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([String: CachedLocation].self, from: data) else {
            return [:]
        }
        return cached
    }
}

// MARK: - Map Annotation

struct StoreAnnotation: Identifiable {
    let id: UUID
    let location: StoreLocation
    
    var coordinate: CLLocationCoordinate2D { location.coordinate }
    var title: String { location.storeName }
    var subtitle: String { location.formattedCityState }
}

// MARK: - Map Helpers

extension Array where Element == StoreLocation {
    /// Convert to annotations for MapKit
    var annotations: [StoreAnnotation] {
        map { StoreAnnotation(id: $0.id, location: $0) }
    }
    
    /// Group by store name
    var groupedByStore: [String: [StoreLocation]] {
        Dictionary(grouping: self) { $0.storeName }
    }
    
    /// Total spent across all locations
    var totalSpent: Double {
        reduce(0) { $0 + $1.totalSpent }
    }
    
    /// Total visit count
    var totalVisits: Int {
        reduce(0) { $0 + $1.visitCount }
    }
}
