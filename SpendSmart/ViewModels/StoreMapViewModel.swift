import SwiftUI
import MapKit
import CoreLocation

// MARK: - Store Map View Model

@MainActor
class StoreMapViewModel: ObservableObject {
    @Published var storeLocations: [StoreLocation] = []
    @Published var selectedLocation: StoreLocation?
    @Published var isLoading = true
    @Published var mapCameraPosition: MapCameraPosition = .automatic
    @Published var mapStyle: MapViewStyle = .standard
    @Published var isPlaying = false
    @Published var visibleLocations: [StoreLocation] = []
    @Published var selectedTimeRange: TimeRange = .allTime
    @Published var mapSearchText: String = ""
    
    var filteredLocations: [StoreLocation] {
        let term = mapSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return visibleLocations }
        return visibleLocations.filter { location in
            location.storeName.lowercased().contains(term)
            || location.address.lowercased().contains(term)
            || (location.city?.lowercased().contains(term) ?? false)
        }
    }

    private let geocodingService = GeocodingService.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let haptics = HapticManager.shared

    // MARK: - Computed Properties

    var topStoreName: String {
        guard let top = storeLocations.max(by: { $0.totalSpent < $1.totalSpent }) else { return "-" }
        return top.storeName
    }

    var uniqueCitiesCount: Int {
        let cities = storeLocations.compactMap { $0.city?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(cities.filter { !$0.isEmpty }).count
    }

    var avgSpendPerVisit: Double {
        guard storeLocations.totalVisits > 0 else { return 0 }
        return storeLocations.totalSpent / Double(storeLocations.totalVisits)
    }

    // MARK: - Data Loading

    func loadStoreLocations() async {
        isLoading = true

        var receipts: [Receipt] = []

        if subscriptionManager.hasCloudWriteAccess {
            do {
                receipts = try await SupabaseManager.shared.fetchReceipts()
            } catch {
                print("📍 [Map] Error fetching receipts: \(error)")
            }
        } else {
            receipts = LocalReceiptStorage.shared.getAllReceipts()
        }

        let receiptsWithAddresses = receipts.filter { !$0.store_address.isEmpty }

        let filteredReceipts: [Receipt]
        if let startDate = selectedTimeRange.startDate {
            filteredReceipts = receiptsWithAddresses.filter { $0.purchase_date >= startDate }
        } else {
            filteredReceipts = receiptsWithAddresses
        }

        let locations = await geocodingService.geocodeStores(from: filteredReceipts)

        storeLocations = locations
        visibleLocations = locations

        if let region = geocodingService.regionForLocations(locations) {
            mapCameraPosition = .region(region)
        }

        isLoading = false
    }

    // MARK: - Playback

    func playTimeLapse() {
        guard !isPlaying, !storeLocations.isEmpty else { return }
        isPlaying = true
        visibleLocations = []

        Task {
            // Sort roughly by date (using the first receipt date for each location)
            let sorted = storeLocations.sorted {
                let d1 = $0.receipts.min(by: { $0.purchase_date < $1.purchase_date })?.purchase_date ?? Date.distantPast
                let d2 = $1.receipts.min(by: { $0.purchase_date < $1.purchase_date })?.purchase_date ?? Date.distantPast
                return d1 < d2
            }

            for location in sorted {
                // Slower pace for effect
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    visibleLocations.append(location)
                }
                haptics.light()
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s hold

            withAnimation {
                isPlaying = false
                visibleLocations = storeLocations // Ensure all are back
            }
        }
    }

    // MARK: - Map Controls

    func focusOnAllLocations() {
        if let region = geocodingService.regionForLocations(storeLocations) {
            withAnimation(.easeInOut(duration: 0.5)) {
                mapCameraPosition = .region(region)
            }
        }
    }

    func heatRadius(for location: StoreLocation) -> CLLocationDistance {
        let base: CLLocationDistance = 180
        let spendBoost = min(location.totalSpent * 1.2, 900)
        let visitsBoost = min(Double(location.visitCount) * 45, 400)
        return base + spendBoost + visitsBoost
    }

    // MARK: - Formatting

    func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(
            code: CurrencyService.shared.preferredCurrency,
            maximumFractionDigits: 0
        )
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
