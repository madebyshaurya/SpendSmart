//
//  StoreLocationManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

/// A class that manages store locations and metrics for the map view
class StoreLocationManager: ObservableObject {
    static let shared = StoreLocationManager()

    @Published var storeLocations: [StoreLocation] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    @Published var selectedTimeFrame: TimeFrame = .allTime
    @Published var selectedCategory: String? = nil
    @Published var showUserLocation: Bool = true
    @Published var priceRange: ClosedRange<Double> = 0...1000
    @Published var searchText: String = ""

    private let userLocationManager = UserLocationManager.shared
    private var cancellables = Set<AnyCancellable>()

    enum TimeFrame: String, CaseIterable, Identifiable {
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        case last6Months = "Last 6 Months"
        case lastYear = "Last Year"
        case allTime = "All Time"

        var id: String { self.rawValue }

        var dateRange: (Date, Date) {
            let endDate = Date()
            let startDate: Date

            switch self {
            case .last30Days:
                startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            case .last90Days:
                startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate)!
            case .last6Months:
                startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate)!
            case .lastYear:
                startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
            case .allTime:
                startDate = Calendar.current.date(byAdding: .year, value: -100, to: endDate)!
            }

            return (startDate, endDate)
        }
    }

    /// Process receipts to extract store locations and metrics
    func processReceipts(_ receipts: [Receipt], completion: (() -> Void)? = nil) {
        isLoading = true

        // Group receipts by store
        let storeGroups = Dictionary(grouping: receipts) { receipt in
            return receipt.store_name
        }

        var locations: [StoreLocation] = []

        // Use a dispatch group to track when all geocoding operations are complete
        let geocodingGroup = DispatchGroup()

        for (storeName, storeReceipts) in storeGroups {
            // Skip if no address
            guard let firstReceipt = storeReceipts.first, !firstReceipt.store_address.isEmpty else {
                continue
            }

            // Calculate metrics
            let visitCount = storeReceipts.count
            let totalSpent = storeReceipts.reduce(0) { $0 + $1.total_amount }
            let averageSpent = totalSpent / Double(visitCount)

            // Get most recent visit
            let mostRecentVisit = storeReceipts.max(by: { $0.purchase_date < $1.purchase_date })?.purchase_date ?? Date()

            // Enter the dispatch group before geocoding
            geocodingGroup.enter()

            // Get coordinate asynchronously
            getCoordinateFor(address: firstReceipt.store_address) { coordinate in
                // Create a store location
                let location = StoreLocation(
                    id: UUID(),
                    name: storeName,
                    address: firstReceipt.store_address,
                    coordinate: coordinate,
                    visitCount: visitCount,
                    totalSpent: totalSpent,
                    averageSpent: averageSpent,
                    lastVisit: mostRecentVisit,
                    receipts: storeReceipts,
                    logoSearchTerm: firstReceipt.logo_search_term ?? storeName
                )

                locations.append(location)

                // Leave the dispatch group after geocoding is complete
                geocodingGroup.leave()
            }
        }

        // When all geocoding operations are complete
        geocodingGroup.notify(queue: .main) {
            self.storeLocations = locations
            self.isLoading = false
            completion?()
        }
    }

    /// Get coordinate for an address asynchronously
    private func getCoordinateFor(address: String, completion: @escaping (CLLocationCoordinate2D) -> Void) {
        // Get user's current location as default if available, otherwise use San Francisco
        let defaultCoordinate = userLocationManager.getCurrentCoordinate()

        // Check if we have this address cached
        if let cachedCoordinate = coordinateCache[address] {
            completion(cachedCoordinate)
            return
        }

        // Create a geocoder and try to get coordinates
        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(address) { placemarks, error in

            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")

                // Generate a random coordinate near the user's location
                let latitudeOffset = Double.random(in: -0.05...0.05)
                let longitudeOffset = Double.random(in: -0.05...0.05)

                let randomCoordinate = CLLocationCoordinate2D(
                    latitude: defaultCoordinate.latitude + latitudeOffset,
                    longitude: defaultCoordinate.longitude + longitudeOffset
                )

                // Cache this random coordinate to ensure consistency
                self.coordinateCache[address] = randomCoordinate
                completion(randomCoordinate)
                return
            }

            if let location = placemarks?.first?.location?.coordinate {
                // Cache the result
                self.coordinateCache[address] = location
                completion(location)
            } else {
                // Generate a random coordinate near the user's location
                let latitudeOffset = Double.random(in: -0.05...0.05)
                let longitudeOffset = Double.random(in: -0.05...0.05)

                let randomCoordinate = CLLocationCoordinate2D(
                    latitude: defaultCoordinate.latitude + latitudeOffset,
                    longitude: defaultCoordinate.longitude + longitudeOffset
                )

                // Cache this random coordinate to ensure consistency
                self.coordinateCache[address] = randomCoordinate
                completion(randomCoordinate)
            }
        }
    }

    /// Filter store locations based on selected time frame, category, price range, and search text
    func filteredLocations() -> [StoreLocation] {
        let (startDate, endDate) = selectedTimeFrame.dateRange
        let searchQuery = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        return storeLocations.compactMap { location in
            // Filter receipts by date range
            let filteredReceipts = location.receipts.filter { receipt in
                return receipt.purchase_date >= startDate && receipt.purchase_date <= endDate
            }

            // Skip if no receipts in range
            guard !filteredReceipts.isEmpty else {
                return nil
            }

            // Apply search filter if search text is not empty
            if !searchQuery.isEmpty {
                let matchesSearch = location.name.lowercased().contains(searchQuery) ||
                                   location.address.lowercased().contains(searchQuery) ||
                                   filteredReceipts.contains { receipt in
                                       receipt.items.contains { item in
                                           item.name.lowercased().contains(searchQuery) ||
                                           (item.category.lowercased().contains(searchQuery))
                                       }
                                   }

                guard matchesSearch else {
                    return nil
                }
            }

            // Apply category filter if selected
            if let category = selectedCategory {
                let categoryReceipts = filteredReceipts.filter { receipt in
                    // Check if any items in the receipt match the category
                    return receipt.items.contains { $0.category == category }
                }

                // Skip if no receipts match category
                guard !categoryReceipts.isEmpty else {
                    return nil
                }

                // Calculate metrics for filtered receipts
                let visitCount = categoryReceipts.count
                let totalSpent = categoryReceipts.reduce(0) { $0 + $1.total_amount }
                let averageSpent = totalSpent / Double(visitCount)
                let mostRecentVisit = categoryReceipts.max(by: { $0.purchase_date < $1.purchase_date })?.purchase_date ?? Date()

                // Skip if total spent is outside the price range
                guard totalSpent >= priceRange.lowerBound && totalSpent <= priceRange.upperBound else {
                    return nil
                }

                // Create a new location with filtered metrics
                return StoreLocation(
                    id: location.id,
                    name: location.name,
                    address: location.address,
                    coordinate: location.coordinate,
                    visitCount: visitCount,
                    totalSpent: totalSpent,
                    averageSpent: averageSpent,
                    lastVisit: mostRecentVisit,
                    receipts: categoryReceipts,
                    logoSearchTerm: location.logoSearchTerm
                )
            }

            // Calculate metrics for time-filtered receipts
            let visitCount = filteredReceipts.count
            let totalSpent = filteredReceipts.reduce(0) { $0 + $1.total_amount }
            let averageSpent = totalSpent / Double(visitCount)
            let mostRecentVisit = filteredReceipts.max(by: { $0.purchase_date < $1.purchase_date })?.purchase_date ?? Date()

            // Skip if total spent is outside the price range
            guard totalSpent >= priceRange.lowerBound && totalSpent <= priceRange.upperBound else {
                return nil
            }

            // Create a new location with filtered metrics
            return StoreLocation(
                id: location.id,
                name: location.name,
                address: location.address,
                coordinate: location.coordinate,
                visitCount: visitCount,
                totalSpent: totalSpent,
                averageSpent: averageSpent,
                lastVisit: mostRecentVisit,
                receipts: filteredReceipts,
                logoSearchTerm: location.logoSearchTerm
            )
        }
    }



    // Cache for coordinates to avoid repeated geocoding
    private var coordinateCache: [String: CLLocationCoordinate2D] = [:]

    /// Helper function to compare two CLLocationCoordinate2D instances
    private func areCoordinatesEqual(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Bool {
        return coord1.latitude == coord2.latitude && coord1.longitude == coord2.longitude
    }

    /// Calculate the optimal map region to show all store locations
    func calculateMapRegion() -> MKCoordinateRegion {
        // Default region centered on user's location
        let userCoordinate = userLocationManager.getCurrentCoordinate()
        let defaultRegion = MKCoordinateRegion(
            center: userCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        // If no locations, return default region centered on user's location
        guard !filteredLocations().isEmpty else {
            return defaultRegion
        }

        // Get all coordinates
        let coordinates = filteredLocations().map { $0.coordinate }

        // Calculate the center point
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLong = longitudes.min(),
              let maxLong = longitudes.max() else {
            return defaultRegion
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLong + maxLong) / 2
        )

        // Calculate the span with some padding
        let latDelta = (maxLat - minLat) * 1.5
        let longDelta = (maxLong - minLong) * 1.5

        // Ensure minimum zoom level
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.02),
            longitudeDelta: max(longDelta, 0.02)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Calculate the maximum price for the price range slider
    func calculateMaxPrice() -> Double {
        // Get the maximum total spent across all store locations
        let maxPrice = storeLocations.map { $0.totalSpent }.max() ?? 1000

        // Round up to the nearest 100 for a cleaner UI
        return ceil(maxPrice / 100) * 100
    }

    /// Update the price range based on the current store locations
    func updatePriceRange() {
        let maxPrice = calculateMaxPrice()
        priceRange = 0...maxPrice
    }
}

/// A struct representing a store location with metrics
struct StoreLocation: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let visitCount: Int
    let totalSpent: Double
    let averageSpent: Double
    let lastVisit: Date
    let receipts: [Receipt]
    let logoSearchTerm: String

    var markerTint: Color {
        // Color based on visit frequency
        if visitCount > 10 {
            return .red
        } else if visitCount > 5 {
            return .orange
        } else if visitCount > 2 {
            return .blue
        } else {
            return .green
        }
    }

    var markerSize: CGFloat {
        // Size based on total spent
        let baseSize: CGFloat = 30
        let maxSize: CGFloat = 60

        if totalSpent > 1000 {
            return maxSize
        } else if totalSpent > 500 {
            return baseSize + 20
        } else if totalSpent > 100 {
            return baseSize + 10
        } else {
            return baseSize
        }
    }
}
