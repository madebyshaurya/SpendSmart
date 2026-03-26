import ConfettiSwiftUI
import SwiftUI

/// Shows results of batch receipt processing — success/failed/retry for each receipt.
struct BatchConfirmationView: View {
    @ObservedObject var processor: BatchReceiptProcessor
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let onSaveAll: ([Receipt]) -> Void
    let onCancel: () -> Void

    @State private var confettiCounter = 0
    @StateObject private var haptics = HapticManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                            .animateEntrance(index: 0)

                        // Receipt cards
                        ForEach(Array(processor.items.enumerated()), id: \.element.id) { index, item in
                            batchItemCard(item: item, index: index)
                                .animateEntrance(index: index + 1)
                        }

                        // Action buttons
                        if processor.allDone {
                            actionButtons
                                .animateEntrance(index: processor.items.count + 1)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        haptics.sheetDismissed()
                        onCancel()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundColor(.brandTextSecondary)
                }
            }
            .confettiCannon(trigger: $confettiCounter, num: 50, colors: [.brandVibrantBlue, .brandSkyBlue, .brandDeepNavy, .white], rainHeight: 800, radius: 400)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("\(processor.processedCount) of \(processor.totalCount) Receipts")
                .font(.instrumentSerifItalic(size: 28))
                .foregroundColor(.brandTextPrimary)
                .contentTransition(.numericText())

            if processor.isProcessing {
                Text("Processing your receipts...")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundColor(.brandTextSecondary)
            } else if processor.failedCount > 0 {
                Text("\(processor.failedCount) failed — tap to retry")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundColor(.brandWarning)
            } else {
                Text("All receipts processed successfully")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundColor(.brandSuccess)
            }
        }
        .animation(.brandSnappy, value: processor.processedCount)
    }

    // MARK: - Batch Item Card

    @ViewBuilder
    private func batchItemCard(item: BatchReceiptProcessor.BatchItem, index: Int) -> some View {
        HStack(spacing: 16) {
            // Receipt thumbnail
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                switch item.status {
                case .pending:
                    Text("Waiting...")
                        .font(.manrope(size: 15, weight: .medium))
                        .foregroundColor(.brandTextTertiary)

                case .processing:
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.manrope(size: 15, weight: .medium))
                            .foregroundColor(.brandTextSecondary)
                    }

                case .success(let response, _):
                    Text(response.store_name ?? "Receipt \(index + 1)")
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundColor(.brandTextPrimary)

                    if let amount = response.total_amount {
                        Text(CurrencyService.shared.formatAmount(amount, currency: CurrencyService.shared.preferredCurrency))
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.brandVibrantBlue)
                            .monospacedDigit()
                    }

                case .failed(let message):
                    Text("Failed")
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundColor(.brandError)

                    Text(message)
                        .font(.manrope(size: 12, weight: .regular))
                        .foregroundColor(.brandTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status icon / retry button
            switch item.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.brandTextTertiary)

            case .processing:
                EmptyView()

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.brandSuccess)
                    .symbolEffect(.bounce, value: processor.processedCount)

            case .failed:
                Button {
                    haptics.buttonPress()
                    Task { await processor.retryItem(at: index) }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.brandVibrantBlue)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground(for: item.status))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder(for: item.status), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed(item) ? 0.97 : 1.0)
        .animation(.brandSnappy, value: processor.processedCount)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if processor.processedCount > 0 {
                Brand3DButton(
                    title: "Save \(processor.processedCount) Receipt\(processor.processedCount == 1 ? "" : "s")",
                    icon: "checkmark",
                    style: .primary
                ) {
                    haptics.celebration()
                    confettiCounter += 1
                    saveAllSuccessful()
                }
            }

            if processor.failedCount > 0 {
                Brand3DButton(title: "Retry All Failed", icon: "arrow.clockwise", style: .secondary) {
                    haptics.buttonPress()
                    Task { await retryAllFailed() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func cardBackground(for status: BatchReceiptProcessor.ItemStatus) -> Color {
        switch status {
        case .success: return Color.brandSuccess.opacity(0.05)
        case .failed: return Color.brandError.opacity(0.05)
        default: return Color.brandSurface
        }
    }

    private func cardBorder(for status: BatchReceiptProcessor.ItemStatus) -> Color {
        switch status {
        case .success: return Color.brandSuccess.opacity(0.2)
        case .failed: return Color.brandError.opacity(0.2)
        default: return Color.brandBorder
        }
    }

    private func isPressed(_ item: BatchReceiptProcessor.BatchItem) -> Bool {
        if case .processing = item.status { return true }
        return false
    }

    private func saveAllSuccessful() {
        var receipts: [Receipt] = []
        for item in processor.items {
            if case .success(let response, let urls) = item.status {
                let receipt = Receipt.from(response: response, imageUrls: urls)
                receipts.append(receipt)
            }
        }
        onSaveAll(receipts)
    }

    private func retryAllFailed() async {
        for (index, item) in processor.items.enumerated() {
            if case .failed = item.status {
                await processor.retryItem(at: index)
            }
        }
    }
}
