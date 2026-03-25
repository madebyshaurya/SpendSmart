import SwiftUI
import CoreLocation
import MapKit

@MainActor
class ReceiptDetailViewModel: ObservableObject {
    let receipt: Receipt

    @Published var storeLocation: StoreLocation?
    @Published var isLoadingLocation = false
    @Published var showRoastPopup = false
    @Published var roastMessage: String = ""
    @Published var isRoasting = false
    @Published var emojiMap: [UUID: String] = [:]

    private let haptics = HapticManager.shared

    init(receipt: Receipt) {
        self.receipt = receipt
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: receipt.currency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func loadStoreLocation() async {
        guard !receipt.store_address.isEmpty else { return }
        isLoadingLocation = true
        if let location = await GeocodingService.shared.geocode(address: receipt.store_address) {
            storeLocation = location
        }
        isLoadingLocation = false
    }

    func openInMaps() {
        guard let location = storeLocation else { return }
        let item = mapItem(for: location)
        item.name = receipt.store_name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    func mapItem(for location: StoreLocation) -> MKMapItem {
        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = receipt.store_name
        return item
    }

    func shareReceipt() {
        let text = """
        Receipt from \(receipt.store_name)
        Date: \(receipt.purchase_date.formatted(date: .long, time: .omitted))
        Total: \(formatCurrency(receipt.total_amount))
        Items: \(receipt.items.count)

        Shared via SpendSmart
        """

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    func shareReceiptImage() {
        let shareCard = ReceiptShareCard(receipt: receipt)
        let renderer = ImageRenderer(content: shareCard.frame(width: 390))
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return }

        let text = "Receipt from \(receipt.store_name) — \(formatCurrency(receipt.total_amount))"
        let activityVC = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        haptics.chaChing()
    }

    func roastReceipt() {
        guard !isRoasting else { return }
        isRoasting = true

        Task {
            let itemsList = receipt.items.map { "\($0.name) ($\($0.price))" }.joined(separator: ", ")
            let prompt = "Roast this specific receipt I just scanned: Store: \(receipt.store_name), Total: \(receipt.total_amount) \(receipt.currency). Items: \(itemsList). Be funny, snarky, and Gen-Z. Keep it short."

            do {
                let response = try await BackendAPIService.shared.chatWithExpenses(message: prompt)
                roastMessage = response.text
                showRoastPopup = true
                isRoasting = false
                haptics.chaChing()
            } catch {
                isRoasting = false
                haptics.error()
            }
        }
    }

    func resolveAllEmojis() async {
        guard !receipt.items.isEmpty else { return }

        var resolved: [UUID: String] = [:]
        await withTaskGroup(of: (UUID, String?).self) { group in
            for item in receipt.items {
                group.addTask {
                    let key = "\(item.name.lowercased())|\(item.category.lowercased())"
                    if let cached = await EmojiResolver.shared.cachedEmoji(for: key) {
                        return (item.id, cached)
                    }

                    let prompt = "Return a single Apple emoji that best represents this receipt item. Item: \(item.name). Category: \(item.category)."
                    let response = try? await AIService.shared.generateContent(
                        prompt: prompt,
                        systemInstruction: "Respond with a single emoji only. No words or punctuation.",
                        config: AIService.GenerationConfig(temperature: 0.2, maxOutputTokens: 8)
                    )
                    if let text = response?.text,
                       let emoji = EmojiResolver.firstEmoji(in: text) {
                        await EmojiResolver.shared.setEmoji(emoji, for: key)
                        return (item.id, emoji)
                    }

                    return (item.id, nil)
                }
            }

            for await (id, emoji) in group {
                if let emoji { resolved[id] = emoji }
            }
        }

        emojiMap = resolved
    }
}
