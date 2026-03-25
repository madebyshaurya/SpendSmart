import SwiftUI

struct ReceiptsListSection: View {
    @ObservedObject var viewModel: ReceiptsViewModel
    @ObservedObject var haptics: HapticManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isAdvancedFilterActive {
                    filterStatusBanner
                }

                HStack {
                    Text("\(viewModel.filteredReceipts.count) receipt\(viewModel.filteredReceipts.count == 1 ? "" : "s")")
                        .font(.manrope(size: 13, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)

                    Spacer()

                    Text(viewModel.sortOption.rawValue)
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                .padding(.horizontal)

                ForEach(Array(viewModel.filteredReceipts.enumerated()), id: \.element.id) { index, receipt in
                    NavigationLink {
                        ReceiptDetailView(
                            receipt: receipt,
                            isLocal: viewModel.isLocalReceipt(receipt),
                            onDelete: {
                                deleteReceipt(receipt)
                            },
                            onUpdate: { updated in
                                await viewModel.updateReceipt(updated)
                            }
                        )
                    } label: {
                        ReceiptCardContent(
                            receipt: receipt,
                            isLocal: viewModel.isLocalReceipt(receipt)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal)
                    .animateEntrance(index: index)
                    .contextMenu {
                        Button {
                            haptics.selection()
                            viewModel.editingReceipt = receipt
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            haptics.buttonPress()
                            shareReceipt(receipt)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            haptics.warning()
                            deleteReceipt(receipt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            haptics.error()
                            deleteReceipt(receipt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            haptics.selection()
                            viewModel.editingReceipt = receipt
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.brandVibrantBlue)
                    }
                }
            }
            .padding(.vertical)
        }
        // .scrollEdgeEffectStyle requires iOS 26
    }

    private var filterStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.brandVibrantBlue)

            Text("Advanced filters active")
                .font(.manrope(size: 13, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)

            Spacer()

            Button {
                haptics.buttonPress()
                viewModel.resetAdvancedFilters()
            } label: {
                Text("Clear")
                    .font(.manrope(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandAccentLight)
        )
        .padding(.horizontal)
    }

    private func deleteReceipt(_ receipt: Receipt) {
        if let index = viewModel.filteredReceipts.firstIndex(where: { $0.id == receipt.id }) {
            viewModel.deleteReceipt(at: IndexSet(integer: index))
        }
    }

    private func shareReceipt(_ receipt: Receipt) {
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: CurrencyService.shared.preferredCurrency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
