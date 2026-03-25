import SwiftUI
import MapKit

struct DashboardMapPreviewSection: View {
    let locations: [StoreLocation]
    @Binding var position: MapCameraPosition
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Store Map")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                Text("\(locations.count) stores")
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            ZStack {
                Map(position: $position) {
                    ForEach(locations) { location in
                        Annotation(location.storeName, coordinate: location.coordinate) {
                            DashboardMapPin(location: location)
                        }
                    }
                }
                .mapStyle(.standard)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandVibrantBlue))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}

private struct DashboardMapPin: View {
    let location: StoreLocation

    var body: some View {
        BrandLogoView(storeName: location.storeName, logoSearchTerm: location.storeName)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}
