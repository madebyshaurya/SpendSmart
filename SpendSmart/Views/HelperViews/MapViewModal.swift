//
//  MapViewModal.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapViewModal: View {
    @Binding var isPresented: Bool
    var receipts: [Receipt]

    @StateObject private var locationManager = StoreLocationManager.shared
    @StateObject private var userLocationManager = UserLocationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    // Search and filter states
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showListView = false
    @State private var maxPrice: Double = 1000
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedLocation: StoreLocation? = nil

    @State private var availableCategories: [String] = []
    @State private var isMapLoaded = false
    @State private var isAnimatingIn = false

    // Break down complex expressions into computed properties
    private var headerBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.8)
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissModal()
                }

            // Main content
            VStack(spacing: 0) {
                headerView

                // Search bar
                MapSearchBar(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    showFilters: .constant(false)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onChange(of: searchText) { _, newValue in
                    locationManager.searchText = newValue
                    updateMapRegion()
                }



                // View toggle
                HStack(spacing: 16) {
                    Button {
                        showListView = false
                    } label: {
                        HStack {
                            Image(systemName: "map")
                                .font(.system(size: 16))
                            Text("Map")
                                .font(.instrumentSans(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(!showListView ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                        )
                        .foregroundColor(!showListView ? .white : (colorScheme == .dark ? .white : .black))
                    }

                    Button {
                        showListView = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16))
                            Text("List")
                                .font(.instrumentSans(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showListView ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                        )
                        .foregroundColor(showListView ? .white : (colorScheme == .dark ? .white : .black))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Content - Map or List view
                if showListView {
                    StoreListView(
                        locations: locationManager.filteredLocations(),
                        onSelectLocation: { location in
                            selectLocation(location)
                            showListView = false // Switch back to map view
                        }
                    )
                } else {
                    // Map content
                    mapContentView
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.7)
            .scaleEffect(isAnimatingIn ? 1 : 0.8)
            .opacity(isAnimatingIn ? 1 : 0)
        }
        .onAppear(perform: setupOnAppear)
    }

    // Extract header view
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Text("Spending Map")
                    .font(.instrumentSans(size: 20, weight: .semibold))
                    .foregroundColor(primaryTextColor)
            }

            Spacer()

            // Location button
            Button {
                withAnimation {
                    locationManager.showUserLocation.toggle()
                }
            } label: {
                locationButtonLabel
            }

            // Close button
            Button {
                dismissModal()
            } label: {
                closeButtonLabel
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(headerBackgroundColor)
    }

    private var locationButtonLabel: some View {
        Image(systemName: locationManager.showUserLocation ? "location.fill" : "location")
            .font(.system(size: 22))
            .foregroundColor(locationManager.showUserLocation ? .blue : primaryTextColor)
            .padding(8)
            .background(
                Circle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
    }



    private var closeButtonLabel: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 22))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.6))
            .padding(8)
    }

    // Extract filter bar view
    private var filterBarView: some View {
        VStack(spacing: 12) {
            // Price range slider
            priceRangeSelector

            Divider()
                .padding(.horizontal, 16)

            timeFrameSelector

            // Category selector
            if !availableCategories.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                categorySelector
            }
        }
        .padding(.vertical, 12)
        .background(secondaryBackgroundColor)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var priceRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price Range")
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, 16)

            HStack {
                Text(CurrencyManager.shared.formatAmount(locationManager.priceRange.lowerBound, currencyCode: CurrencyManager.shared.preferredCurrency))
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Text(CurrencyManager.shared.formatAmount(locationManager.priceRange.upperBound, currencyCode: CurrencyManager.shared.preferredCurrency))
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            RangeSlider(value: $locationManager.priceRange, in: 0...maxPrice)
                .frame(height: 30)
                .padding(.horizontal, 16)
                .onChange(of: locationManager.priceRange) { _, _ in
                    updateMapRegion()
                }
        }
    }

    private var timeFrameSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StoreLocationManager.TimeFrame.allCases) { timeFrame in
                    timeFrameButton(timeFrame)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func timeFrameButton(_ timeFrame: StoreLocationManager.TimeFrame) -> some View {
        Button {
            locationManager.selectedTimeFrame = timeFrame
            updateMapRegion()
        } label: {
            Text(timeFrame.rawValue)
                .font(.instrumentSans(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(timeFrameBackgroundColor(for: timeFrame))
                )
                .foregroundColor(timeFrameTextColor(for: timeFrame))
        }
    }

    private func timeFrameBackgroundColor(for timeFrame: StoreLocationManager.TimeFrame) -> Color {
        locationManager.selectedTimeFrame == timeFrame ?
            Color.blue :
            (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
    }

    private func timeFrameTextColor(for timeFrame: StoreLocationManager.TimeFrame) -> Color {
        locationManager.selectedTimeFrame == timeFrame ?
            .white :
            (colorScheme == .dark ? .white : .black)
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" option
                allCategoriesButton

                // Category options
                ForEach(availableCategories, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var allCategoriesButton: some View {
        Button {
            locationManager.selectedCategory = nil
            updateMapRegion()
        } label: {
            Text("All Categories")
                .font(.instrumentSans(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryBackgroundColor(for: nil))
                )
                .foregroundColor(categoryTextColor(for: nil))
        }
    }

    private func categoryButton(_ category: String) -> some View {
        Button {
            locationManager.selectedCategory = category
            updateMapRegion()
        } label: {
            Text(category)
                .font(.instrumentSans(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryBackgroundColor(for: category))
                )
                .foregroundColor(categoryTextColor(for: category))
        }
    }

    private func categoryBackgroundColor(for category: String?) -> Color {
        let isSelected = (category == nil && locationManager.selectedCategory == nil) ||
                         (category != nil && locationManager.selectedCategory == category)

        return isSelected ?
            Color.green :
            (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
    }

    private func categoryTextColor(for category: String?) -> Color {
        let isSelected = (category == nil && locationManager.selectedCategory == nil) ||
                         (category != nil && locationManager.selectedCategory == category)

        return isSelected ?
            .white :
            (colorScheme == .dark ? .white : .black)
    }

    private func updateMapRegion() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let newRegion = locationManager.calculateMapRegion()
            mapRegion = newRegion

            // Update the map position for iOS 17+
            if #available(iOS 17.0, *) {
                mapPosition = .region(newRegion)
            }
        }
    }

    // Extract map content view
    private var mapContentView: some View {
        ZStack {
            mapView

            // Loading indicator
            if locationManager.isLoading {
                loadingView
            }

            // Empty state
            if !locationManager.isLoading && locationManager.filteredLocations().isEmpty {
                emptyStateView
            }

            // Selected location detail card
            if let location = selectedLocation {
                selectedLocationView(location)
            }
        }
    }

    private var mapView: some View {
        // Use the new Map API with MapContentBuilder for iOS 17+
        if #available(iOS 17.0, *) {
            return Map(position: $mapPosition, interactionModes: .all) {
                // Store locations
                ForEach(locationManager.filteredLocations()) { location in
                    Annotation("", coordinate: location.coordinate) {
                        MapMarkerView(storeLocation: location)
                            .onTapGesture {
                                selectLocation(location)
                            }
                    }
                    .annotationTitles(.hidden)
                }

                // User location marker is automatically shown
                if locationManager.showUserLocation {
                    UserAnnotation()
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()
            .onTapGesture {
                // Deselect location when tapping on the map (not on a marker)
                deselectLocation()
            }
            .onDisappear {
                userLocationManager.stopUpdatingLocation()
            }
            .opacity(isMapLoaded ? 1 : 0)
        } else {
            // Fallback for iOS 16 and earlier
            return Map(coordinateRegion: $mapRegion,
                       showsUserLocation: locationManager.showUserLocation,
                       annotationItems: locationManager.filteredLocations()) { location in
                MapAnnotation(coordinate: location.coordinate) {
                    MapMarkerView(storeLocation: location)
                        .onTapGesture {
                            selectLocation(location)
                        }
                }
            }
            .ignoresSafeArea()
            .onTapGesture {
                // Deselect location when tapping on the map (not on a marker)
                deselectLocation()
            }
            .onDisappear {
                userLocationManager.stopUpdatingLocation()
            }
            .opacity(isMapLoaded ? 1 : 0)
        }
    }

    private func selectLocation(_ location: StoreLocation) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedLocation = location

            // Center map on selected location with a closer zoom
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )

            mapRegion = region

            // Update the map position for iOS 17+
            if #available(iOS 17.0, *) {
                mapPosition = .region(region)
            }
        }
    }

    private func deselectLocation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedLocation = nil
        }
    }



    private var loadingView: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(colorScheme == .dark ? .white : .blue)

                Text("Loading store locations...")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(primaryTextColor)
            }
        }
    }

    private var emptyStateView: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)

                Text("No store locations found")
                    .font(.instrumentSans(size: 18, weight: .medium))
                    .foregroundColor(primaryTextColor)

                Text("Try adjusting your filters or add more receipts with location data")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private func selectedLocationView(_ location: StoreLocation) -> some View {
        VStack {
            Spacer()

            StoreDetailCard(storeLocation: location)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    // Setup on appear
    private func setupOnAppear() {
        // Request location permission
        userLocationManager.requestLocationPermission()
        userLocationManager.startUpdatingLocation()

        // Add a loading state
        isMapLoaded = false
        locationManager.isLoading = true

        // Process receipts to extract store locations with completion handler
        locationManager.processReceipts(receipts) {
            // Extract available categories
            extractCategories()

            // Initialize price range filter
            maxPrice = locationManager.calculateMaxPrice()
            locationManager.priceRange = 0...maxPrice

            // Reset search text
            searchText = ""
            locationManager.searchText = ""

            // Update map region to show all locations
            let newRegion = locationManager.calculateMapRegion()
            mapRegion = newRegion

            // Update the map position for iOS 17+
            if #available(iOS 17.0, *) {
                mapPosition = .region(newRegion)
            }

            // Animate the map in after everything is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isMapLoaded = true
                }
            }
        }

        // Animate in the modal
        animateIn()
    }

    private func extractCategories() {
        let allCategories = Set(receipts.flatMap { receipt in
            receipt.items.compactMap { $0.category }
        })
        availableCategories = Array(allCategories).sorted()
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isAnimatingIn = true
        }
    }

    private func dismissModal() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAnimatingIn = false
        }

        // Delay dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}
