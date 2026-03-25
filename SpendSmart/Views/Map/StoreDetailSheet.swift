import SwiftUI
import CoreLocation
import MapKit

// MARK: - StoreDetailSheet
/// Bottom sheet showing store details and receipt history

struct StoreDetailSheet: View {
    let location: StoreLocation
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var haptics = HapticManager.shared
    @StateObject private var locationManager = StoreDistanceManager()
    
    @State private var showAllReceipts = false
    @State private var distanceString: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Store header
                    storeHeader
                    
                    // Stats row
                    statsRow
                    
                    // Mini map
                    miniMapView
                    
                    // Recent receipts
                    recentReceiptsSection
                }
                .padding()
            }
            .background(Color.brandBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        haptics.sheetDismissed()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Store Header
    
    private var storeHeader: some View {
        VStack(spacing: 12) {
            // Store logo
            BrandLogoView(
                storeName: location.storeName,
                logoSearchTerm: location.storeName
            )
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 12, y: 4)
            
            // Store name
            Text(location.storeName)
                .font(.instrumentSerifItalic(size: 24))
                .foregroundStyle(Color.brandTextPrimary)
                .multilineTextAlignment(.center)
            
            // Address
            VStack(spacing: 4) {
                Text(location.address)
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                
                if !location.formattedCityState.isEmpty {
                    Text(location.formattedCityState)
                        .font(.manrope(size: 13, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                
                // Distance from user
                if let distance = distanceString {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(distance)
                            .font(.manrope(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.brandVibrantBlue)
                    .padding(.top, 4)
                }
            }
            .onAppear {
                calculateDistance()
            }
            
            // Open in Maps button
            Button {
                haptics.buttonPress()
                openInMaps()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Open in Maps")
                        .font(.manrope(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.brandVibrantBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.brandAccentLight)
                )
            }
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            // Total spent
            StoreStatCard(
                title: "Total Spent",
                value: formatCurrency(location.totalSpent),
                icon: "dollarsign.circle.fill",
                color: .brandVibrantBlue
            )
            
            Divider()
                .frame(height: 40)
            
            // Visits
            StoreStatCard(
                title: "Visits",
                value: "\(location.visitCount)",
                icon: "figure.walk",
                color: .brandSuccess
            )
            
            Divider()
                .frame(height: 40)
            
            // Avg spend
            StoreStatCard(
                title: "Avg Spend",
                value: formatCurrency(location.visitCount > 0 ? location.totalSpent / Double(location.visitCount) : 0),
                icon: "chart.line.uptrend.xyaxis",
                color: .brandWarning
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Mini Map View
    
    private var miniMapView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.manrope(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextSecondary)
            
            Map(position: .constant(.region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))), interactionModes: []) {
                Marker(location.storeName, coordinate: location.coordinate)
                    .tint(Color.brandVibrantBlue)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Recent Receipts Section
    
    private var recentReceiptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Receipts")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextSecondary)
                
                Spacer()
                
                if location.receipts.count > 3 {
                    Button {
                        haptics.buttonPress()
                        showAllReceipts.toggle()
                    } label: {
                        Text(showAllReceipts ? "Show Less" : "See All")
                            .font(.manrope(size: 13, weight: .medium))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }
            
            // Receipt list
            VStack(spacing: 8) {
                let receiptsToShow = showAllReceipts ? location.receipts : Array(location.receipts.prefix(3))
                
                ForEach(receiptsToShow) { receipt in
                    ReceiptRow(receipt: receipt)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var storeInitials: String {
        let words = location.storeName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(location.storeName.prefix(2)).uppercased()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: CurrencyService.shared.preferredCurrency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.storeName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func calculateDistance() {
        locationManager.requestLocation { userLocation in
            guard let userLocation = userLocation else { return }
            
            let storeLocation = CLLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let userCLLocation = CLLocation(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            let distanceMeters = userCLLocation.distance(from: storeLocation)
            
            // Convert to miles (US) or km based on locale
            let usesMetric = Locale.current.measurementSystem == .metric
            
            if usesMetric {
                let distanceKm = distanceMeters / 1000.0
                if distanceKm < 1 {
                    distanceString = String(format: "%.0f m away", distanceMeters)
                } else {
                    distanceString = String(format: "%.1f km away", distanceKm)
                }
            } else {
                let distanceMiles = distanceMeters / 1609.344
                if distanceMiles < 0.1 {
                    let feet = distanceMeters * 3.28084
                    distanceString = String(format: "%.0f ft away", feet)
                } else {
                    distanceString = String(format: "%.1f mi away", distanceMiles)
                }
            }
        }
    }
}

// MARK: - Stat Card

private struct StoreStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.ibmPlexMono(size: 16))
                .fontWeight(.bold)
                .foregroundStyle(Color.brandTextPrimary)
            
            Text(title)
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Receipt Row

private struct ReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Date indicator
            VStack(spacing: 2) {
                Text(receipt.purchase_date.formatted(.dateTime.day()))
                    .font(.ibmPlexMono(size: 16))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(receipt.purchase_date.formatted(.dateTime.month(.abbreviated)))
                    .font(.manrope(size: 10, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                    .textCase(.uppercase)
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brandSurfaceElevated)
            )
            
            // Receipt info
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.receipt_name.isEmpty ? receipt.store_name : receipt.receipt_name)
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .lineLimit(1)
                
                Text("\(receipt.items.count) items")
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                CurrencyText(amount: receipt.total_amount, currency: receipt.currency)
                    .font(.ibmPlexMono(size: 15))
                    .foregroundStyle(Color.brandTextPrimary)

                if receipt.currency != CurrencyService.shared.preferredCurrency {
                    Text("Converted from \(receipt.currency)")
                        .font(.manrope(size: 10, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: CurrencyService.shared.preferredCurrency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Preview

#Preview {
    StoreDetailSheet(location: StoreLocation(
        id: UUID(),
        address: "123 Main St, San Francisco, CA 94102",
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        storeName: "Trader Joe's",
        city: "San Francisco",
        state: "CA"
    ))
}

// MARK: - Store Distance Manager

final class StoreDistanceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        
        let status = locationManager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            completion(nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            completion?(nil)
            return
        }
        Task { @MainActor in
            self.completion?(location.coordinate)
            self.completion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Distance calculation error: \(error.localizedDescription)")
        Task { @MainActor in
            self.completion?(nil)
            self.completion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}
