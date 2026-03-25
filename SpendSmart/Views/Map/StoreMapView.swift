import SwiftUI
import MapKit
import UIKit
import CoreLocation

// MARK: - StoreMapView
/// Interactive map showing all stores from user's receipts

struct StoreMapView: View {
    @StateObject private var viewModel = StoreMapViewModel()
    @StateObject private var haptics = HapticManager.shared
    @StateObject private var locationManager = UserLocationManager()
    
    // UI State
    @State private var showDetailSheet = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingShare = false
    @State private var showFilters = false
    
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.storeLocations.isEmpty {
                    emptyStateView
                } else {
                    mapContent
                }
            }
            .searchable(
                text: $viewModel.mapSearchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search stores on map..."
            )
            .navigationTitle("Spend Map")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadStoreLocations()
            }
            .onChange(of: viewModel.selectedTimeRange) { _, _ in
                Task { await viewModel.loadStoreLocations() }
            }
            .onChange(of: viewModel.mapSearchText) { _, newValue in
                if let match = viewModel.filteredLocations.first, !newValue.isEmpty {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        viewModel.mapCameraPosition = .region(MKCoordinateRegion(
                            center: match.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                if let location = viewModel.selectedLocation {
                    StoreDetailSheet(location: location)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showFilters) {
                MapFilterSheet(selectedTimeRange: $viewModel.selectedTimeRange)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                }
            }
        }
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        ZStack(alignment: .top) {
            // Map
            Map(position: $viewModel.mapCameraPosition, selection: $viewModel.selectedLocation) {
                // Show user location
                UserAnnotation()
                
                ForEach(viewModel.filteredLocations) { location in
                    MapCircle(center: location.coordinate, radius: viewModel.heatRadius(for: location))
                        .foregroundStyle(Color.brandVibrantBlue.opacity(0.12))
                        .stroke(Color.brandVibrantBlue.opacity(0.2), lineWidth: 1)
                }

                ForEach(viewModel.filteredLocations) { location in
                    Annotation(
                        location.storeName,
                        coordinate: location.coordinate,
                        anchor: .bottom
                    ) {
                        StoreMapPin(
                            location: location,
                            isSelected: viewModel.selectedLocation?.id == location.id
                        )
                        .onTapGesture {
                            haptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedLocation = location
                                showDetailSheet = true
                            }
                        }
                    }
                    .tag(location)
                }
            }
            .mapStyle(viewModel.mapStyle.mapKitStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                locationManager.startUpdating()
            }
            .onDisappear {
                locationManager.stopUpdating()
            }
            
            // Top overlay with stats and controls
            VStack(spacing: 0) {
                topStatsBar
                
                // Map style toggle and recenter button
                HStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        mapStyleButton
                        recenterButton
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }

            VStack {
                Spacer()
                recapCard
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                    .opacity(viewModel.isPlaying ? 0 : 1)
                    .animation(.easeInOut, value: viewModel.isPlaying)
            }
        }
    }
    
    // MARK: - Recenter Button
    
    private var recenterButton: some View {
        Button {
            haptics.selection()
            centerOnUserLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                )
        }
        .disabled(locationManager.userLocation == nil)
        .opacity(locationManager.userLocation == nil ? 0.5 : 1.0)
    }
    
    private func centerOnUserLocation() {
        guard let userLocation = locationManager.userLocation else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            viewModel.mapCameraPosition = .region(MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        }
    }
    
    // MARK: - Top Stats Bar
    
    private var topStatsBar: some View {
        HStack(spacing: 16) {
            // Location count
            StatPill(
                icon: "mappin.circle.fill",
                value: "\(viewModel.storeLocations.count)",
                label: "Stores"
            )
            
            // Total visits
            StatPill(
                icon: "figure.walk",
                value: "\(viewModel.storeLocations.totalVisits)",
                label: "Visits"
            )
            
            // Total spent
            StatPill(
                icon: "dollarsign.circle.fill",
                value: viewModel.formatCurrency(viewModel.storeLocations.totalSpent),
                label: "Spent"
            )
            
            Spacer()
            
            // Playback button
            Button {
                haptics.buttonPress()
                viewModel.playTimeLapse()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            .disabled(viewModel.isPlaying)
            
            // Filter button
            Button {
                haptics.buttonPress()
                showFilters.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Map Style Button
    
    private var mapStyleButton: some View {
        Menu {
            ForEach(MapViewStyle.allCases, id: \.self) { style in
                Button {
                    haptics.selection()
                    withAnimation {
                        viewModel.mapStyle = style
                    }
                } label: {
                    Label(style.displayName, systemImage: style.icon)
                }
            }
            Button {
                haptics.selection()
                viewModel.focusOnAllLocations()
            } label: {
                Label("Fit All", systemImage: "scope")
            }
        } label: {
            Image(systemName: "map.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                )
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.brandVibrantBlue)
                    .symbolEffect(.variableColor.iterative)
            }
            
            Text("Loading Stores")
                .font(.instrumentSerifItalic(size: 24))
                .foregroundColor(.brandTextPrimary)
            
            Text("Geocoding your receipt locations...")
                .font(.manrope(size: 14, weight: .medium))
                .foregroundColor(.brandTextSecondary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandVibrantBlue))
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        EmptyStateView(type: .map)
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spend Map Recap")
                        .font(.instrumentSerifItalic(size: 22))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text(viewModel.selectedTimeRange.rawValue)
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                }

                Spacer()

                Button {
                    haptics.buttonPress()
                    Task { await generateShareImage() }
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingShare {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Share")
                            .font(.manrope(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(LinearGradient.brandPrimary)
                    )
                }
                .disabled(isGeneratingShare)
            }

            HStack(spacing: 12) {
                RecapPill(title: "Cities", value: "\(viewModel.uniqueCitiesCount)")
                RecapPill(title: "Top Store", value: viewModel.topStoreName)
                RecapPill(title: "Avg/Visit", value: viewModel.formatCurrency(viewModel.avgSpendPerVisit))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.clear)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
        )
    }

    private func generateShareImage() async {
        guard !isGeneratingShare else { return }
        isGeneratingShare = true
        let card = SpendMapShareCard(
            title: "Spend Map Recap",
            range: viewModel.selectedTimeRange.rawValue,
            totalSpent: viewModel.formatCurrency(viewModel.storeLocations.totalSpent),
            totalStores: "\(viewModel.storeLocations.count)",
            totalVisits: "\(viewModel.storeLocations.totalVisits)",
            topStore: viewModel.topStoreName,
            cities: "\(viewModel.uniqueCitiesCount)"
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = displayScale
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
        isGeneratingShare = false
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandVibrantBlue)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.ibmPlexMono(size: 14))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(label)
                    .font(.manrope(size: 10, weight: .medium))
                    .foregroundStyle(Color.brandTextTertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct RecapPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.manrope(size: 10, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
                .lineLimit(1)
            Text(value)
                .font(.ibmPlexMono(size: 12))
                .fontWeight(.bold)
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}

private struct SpendMapShareCard: View {
    let title: String
    let range: String
    let totalSpent: String
    let totalStores: String
    let totalVisits: String
    let topStore: String
    let cities: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.instrumentSerifItalic(size: 28))
                        .foregroundStyle(.white)
                    Text(range)
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandSkyBlue)
                }
                Spacer()
                Image(systemName: "map.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 12) {
                ShareStat(title: "Spent", value: totalSpent)
                ShareStat(title: "Stores", value: totalStores)
                ShareStat(title: "Visits", value: totalVisits)
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Store")
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandSkyBlue)
                    Text(topStore)
                        .font(.manrope(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Cities")
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandSkyBlue)
                    Text(cities)
                        .font(.ibmPlexMono(size: 18))
                        .foregroundStyle(.white)
                }
            }

            Text("Made with SpendSmart")
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.brandDeepNavy, Color.brandRoyalBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct ShareStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.manrope(size: 10, weight: .medium))
                .foregroundStyle(Color.brandSkyBlue)
            Text(value)
                .font(.ibmPlexMono(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.12))
        )
    }
}

// MARK: - Store Map Pin

struct StoreMapPin: View {
    let location: StoreLocation
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Pin head
            ZStack {
                RoundedRectangle(cornerRadius: isSelected ? 14 : 12)
                    .fill(Color.white)
                    .frame(width: isSelected ? 52 : 44, height: isSelected ? 52 : 44)
                    .shadow(color: .black.opacity(0.25), radius: isSelected ? 10 : 6, y: 3)

                BrandLogoView(storeName: location.storeName, logoSearchTerm: location.storeName)
                    .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
                    .clipShape(RoundedRectangle(cornerRadius: isSelected ? 10 : 8))
            }
            
            // Pin tail
            Triangle()
                .fill(isSelected ? Color.brandVibrantBlue : Color.brandDeepNavy)
                .frame(width: 16, height: 10)
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Map View Style

enum MapViewStyle: String, CaseIterable {
    case standard
    case satellite
    case hybrid
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "map.fill"
        }
    }
    
    var mapKitStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}

// TimeRange enum is defined in Models/TimeRange.swift

private struct MapFilterSheet: View {
    @Binding var selectedTimeRange: TimeRange

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 40, height: 5)
                .padding(.top, 6)

            Text("Filter Map")
                .font(.instrumentSerifItalic(size: 24))
                .foregroundStyle(Color.brandTextPrimary)

            VStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                    } label: {
                        HStack {
                            Text(range.rawValue)
                                .font(.manrope(size: 15, weight: .semibold))
                                .foregroundStyle(Color.brandTextPrimary)
                            Spacer()
                            if selectedTimeRange == range {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brandVibrantBlue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedTimeRange == range ? Color.brandAccentLight : Color.brandSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom, 24)
    }
}

// MARK: - User Location Manager

final class UserLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            requestLocationPermission()
        }
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
    }
}

// MARK: - Preview

#Preview {
    StoreMapView()
}
