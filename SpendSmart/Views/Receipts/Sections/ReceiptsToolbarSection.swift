import SwiftUI

struct ReceiptsSortMenu: View {
    @ObservedObject var viewModel: ReceiptsViewModel
    @ObservedObject var haptics: HapticManager

    var body: some View {
        Menu {
            ForEach(ReceiptsViewModel.SortOption.allCases, id: \.self) { option in
                Button {
                    haptics.selection()
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.sortOption = option
                    }
                } label: {
                    Label(
                        option.rawValue,
                        systemImage: viewModel.sortOption == option ? "checkmark" : option.icon
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.brandVibrantBlue)
        }
    }
}

struct ReceiptsAdvancedFilterButton: View {
    @ObservedObject var viewModel: ReceiptsViewModel
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var haptics: HapticManager
    @Binding var showAdvancedFilters: Bool

    var body: some View {
        Button {
            haptics.buttonPress()
            showAdvancedFilters = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(
                    systemName: viewModel.isAdvancedFilterActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                )
                .font(.system(size: 18))
                .foregroundStyle(
                    viewModel.isAdvancedFilterActive ? Color.brandVibrantBlue : Color.brandTextSecondary
                )
            }
        }
        .accessibilityLabel("Advanced Search")
    }
}
