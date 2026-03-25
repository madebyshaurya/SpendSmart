import PhotosUI
import SwiftUI

// MARK: - Receipts View

struct ReceiptsView: View {
    @StateObject private var viewModel = ReceiptsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    
    @State private var showAdvancedFilters = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredReceipts.isEmpty {
                    emptyStateView
                } else {
                    ReceiptsListSection(viewModel: viewModel, haptics: haptics)
                }
            }
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search receipts..."
            )
            .searchScopes($viewModel.searchScope, activation: .onSearchPresentation) {
                ForEach(ReceiptsViewModel.SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .searchSuggestions {
                if viewModel.searchText.isEmpty {
                    if !viewModel.recentStoreNames.isEmpty {
                        Section("Recent Stores") {
                            ForEach(viewModel.recentStoreNames, id: \.self) { store in
                                Label(store, systemImage: "storefront")
                                    .searchCompletion(store)
                            }
                        }
                    }
                    if !viewModel.popularCategories.isEmpty {
                        Section("Categories") {
                            ForEach(viewModel.popularCategories, id: \.self) { category in
                                Label(category, systemImage: "tag")
                                    .searchCompletion(category)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Receipts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ReceiptsSortMenu(viewModel: viewModel, haptics: haptics)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ReceiptsAdvancedFilterButton(
                        viewModel: viewModel,
                        subscriptionManager: subscriptionManager,
                        haptics: haptics,
                        showAdvancedFilters: $showAdvancedFilters
                    )
                }
            }
            .refreshable {
                haptics.pullToRefresh()
                await viewModel.loadReceipts()
            }
            .task { await viewModel.loadReceipts() }
            .sheet(item: $viewModel.editingReceipt) { r in
                EditReceiptView(
                    receipt: r,
                    isLocalReceipt: viewModel.isLocalReceipt(r)
                ) { await viewModel.updateReceipt($0) }
            }
            .sheet(isPresented: $showAdvancedFilters) {
                AdvancedSearchSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .hapticOnChange(of: viewModel.sortOption, type: .selection)
            .hapticOnChange(of: viewModel.filteredReceipts.count, type: .light)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        // Skeleton loading state - feels 36% faster than spinners
        ReceiptListSkeletonView()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        if viewModel.searchText.isEmpty && !viewModel.isAdvancedFilterActive {
            // No receipts at all
            EmptyStateView(type: .receipts, action: nil, actionTitle: nil)
        } else {
            // Search/filter returned no results
            EmptyStateView(type: .receiptsSearch, action: {
                haptics.buttonPress()
                viewModel.searchText = ""
                viewModel.searchScope = .all
                viewModel.resetAdvancedFilters()
            }, actionTitle: "Clear Filters")
        }
    }
    
    // MARK: - Receipts List
}

// MARK: - Receipt Card Content (for NavigationLink)

struct ReceiptCardContent: View {
    let receipt: Receipt
    let isLocal: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Store logo
            BrandLogoView(
                storeName: receipt.store_name,
                logoSearchTerm: receipt.logo_search_term
            )
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Receipt info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(receipt.store_name.isEmpty ? "Unknown Store" : receipt.store_name)
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                        .lineLimit(1)
                    
                    StorageIndicatorBadge(isLocal: isLocal)
                }
                
                HStack(spacing: 6) {
                    Text(receipt.purchase_date.formatted(date: .abbreviated, time: .omitted))
                        .font(.manrope(size: 12, weight: .regular))
                        .foregroundStyle(Color.brandTextTertiary)
                    
                    if receipt.items.count > 0 {
                        Text("•")
                            .foregroundStyle(Color.brandTextTertiary)
                        
                        Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                            .font(.manrope(size: 12, weight: .regular))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                CurrencyText(amount: receipt.total_amount, currency: receipt.currency)
                    .font(.ibmPlexMono(size: 16))
                    .monospacedDigit()
                    .foregroundStyle(Color.brandTextPrimary)
                
                if receipt.savings > 0 {
                    CurrencyText(amount: -receipt.savings, currency: receipt.currency)
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandSuccess)
                }

                if receipt.currency != CurrencyService.shared.preferredCurrency {
                    Text("Converted from \(receipt.currency)")
                        .font(.manrope(size: 10, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: CurrencyService.shared.preferredCurrency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Receipt Card (with tap action - for backward compatibility)

struct ReceiptCard: View {
    let receipt: Receipt
    let isLocal: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ReceiptCardContent(receipt: receipt, isLocal: isLocal)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.brandSnappy, value: configuration.isPressed)
    }
}

// MARK: - Advanced Search Sheet

struct AdvancedSearchSheet: View {
    @ObservedObject var viewModel: ReceiptsViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandVibrantBlue)
                        
                        Text("Advanced Search")
                            .font(.instrumentSerifItalic(size: 24))
                            .foregroundStyle(Color.brandTextPrimary)
                        
                        Text("Find exactly what you're looking for")
                            .font(.manrope(size: 14, weight: .regular))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(.top)
                    
                    // Free filters
                    VStack(alignment: .leading, spacing: 16) {
                        filterSectionHeader(title: "Store", icon: "storefront.fill")
                        
                        VStack(spacing: 12) {
                            FilterTextField(
                                placeholder: "Store name or receipt title",
                                text: $viewModel.advancedStoreName,
                                icon: "building.2"
                            )
                            
                            FilterTextField(
                                placeholder: "Location or address",
                                text: $viewModel.advancedLocation,
                                icon: "mappin"
                            )
                        }
                    }
                    .padding()
                    .background(filterCardBackground)
                    
                    // Item search (free for everyone)
                    VStack(alignment: .leading, spacing: 16) {
                        filterSectionHeader(title: "Item Search", icon: "cart.fill")
                        
                        FilterTextField(
                            placeholder: "Item name or category",
                            text: $viewModel.advancedItemQuery,
                            icon: "tag"
                        )
                    }
                    .padding()
                    .background(filterCardBackground)
                    
                    // Date filter (Plus only)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            filterSectionHeader(title: "Date Range", icon: "calendar")
                            Spacer()
                            PlusBadge()
                        }
                        
                        VStack(spacing: 12) {
                            Picker("Mode", selection: $viewModel.dateFilterMode) {
                                ForEach(ReceiptsViewModel.DateFilterMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(!subscriptionManager.isPlus)
                            
                            if subscriptionManager.isPlus {
                                switch viewModel.dateFilterMode {
                                case .any:
                                    EmptyView()
                                case .exact:
                                    DatePicker("On", selection: $viewModel.dateExact, displayedComponents: .date)
                                        .font(.manrope(size: 14))
                                case .range:
                                    DatePicker("From", selection: $viewModel.dateStart, displayedComponents: .date)
                                        .font(.manrope(size: 14))
                                    DatePicker("To", selection: $viewModel.dateEnd, displayedComponents: .date)
                                        .font(.manrope(size: 14))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(filterCardBackground)
                    .overlay(
                        Group {
                            if !subscriptionManager.isPlus {
                                lockedOverlay
                            }
                        }
                    )
                    
                    // Amount filter (Plus only)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            filterSectionHeader(title: "Amount Range", icon: "dollarsign.circle")
                            Spacer()
                            PlusBadge()
                        }
                        
                        VStack(spacing: 12) {
                            Picker("Mode", selection: $viewModel.totalFilterMode) {
                                ForEach(ReceiptsViewModel.TotalFilterMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(!subscriptionManager.isPlus)
                            
                            if subscriptionManager.isPlus {
                                switch viewModel.totalFilterMode {
                                case .any:
                                    EmptyView()
                                case .exact:
                                    FilterTextField(
                                        placeholder: "Exact amount",
                                        text: $viewModel.totalExactInput,
                                        icon: "dollarsign",
                                        keyboardType: .decimalPad
                                    )
                                case .range:
                                    HStack(spacing: 12) {
                                        FilterTextField(
                                            placeholder: "Min",
                                            text: $viewModel.totalMinInput,
                                            icon: "arrow.down",
                                            keyboardType: .decimalPad
                                        )
                                        FilterTextField(
                                            placeholder: "Max",
                                            text: $viewModel.totalMaxInput,
                                            icon: "arrow.up",
                                            keyboardType: .decimalPad
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(filterCardBackground)
                    .overlay(
                        Group {
                            if !subscriptionManager.isPlus {
                                lockedOverlay
                            }
                        }
                    )
                    
                    // Upgrade CTA for non-Plus users
                    if !subscriptionManager.isPlus {
                        upgradeCard
                    }
                }
                .padding()
            }
            .background(Color.brandBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        haptics.buttonPress()
                        viewModel.resetAdvancedFilters()
                    } label: {
                        Text("Clear")
                            .font(.manrope(size: 16, weight: .medium))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        haptics.buttonPress()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.manrope(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }
        }
    }
    
    private func filterSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandVibrantBlue)
            
            Text(title)
                .font(.manrope(size: 15, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)
        }
    }
    
    private var filterCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
    }
    
    private var lockedOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandBackground.opacity(0.7))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandTextTertiary)
                    
                    Text("Plus Feature")
                        .font(.manrope(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                }
            )
            .allowsHitTesting(false)
    }
    
    private var upgradeCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandVibrantBlue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandVibrantBlue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Advanced Search")
                        .font(.manrope(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text("Filter by date range, exact amount, and more")
                        .font(.manrope(size: 13, weight: .regular))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                
                Spacer()
            }
            
            Button {
                haptics.buttonPress()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    subscriptionManager.presentPaywall(trigger: .featureLocked("Advanced Search"))
                }
            } label: {
                HStack {
                    Text("Upgrade to Plus")
                        .font(.manrope(size: 15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient.brandPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandAccentLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandVibrantBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Filter Text Field

struct FilterTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "magnifyingglass"
    var isLocked: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
            
            TextField(placeholder, text: $text)
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextPrimary)
                .keyboardType(keyboardType)
                .disabled(isLocked)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
        .opacity(isLocked ? 0.5 : 1)
    }
}

// MARK: - Plus Badge

struct PlusBadge: View {
    var body: some View {
        Text("PLUS")
            .font(.manrope(size: 10, weight: .bold))
            .foregroundStyle(Color.brandVibrantBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.brandAccentLight)
            )
    }
}

// MARK: - Receipt Items List

struct ReceiptItemsList: View {
    let items: [ReceiptItem]
    @State private var emojiMap: [UUID: String] = [:]

    var body: some View {
        Group {
            ForEach(items) { item in
                ReceiptItemRow(
                    item: item,
                    useEmoji: useEmoji,
                    emoji: emojiMap[item.id]
                )
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
                )
                .listRowSeparator(.hidden)
            }
        }
        .task(id: itemsKey) { await resolveAllEmojis() }
    }

    private var useEmoji: Bool {
        !items.isEmpty && items.allSatisfy { emojiMap[$0.id] != nil }
    }

    private var itemsKey: String {
        items.map { $0.id.uuidString }.joined(separator: "|")
    }

    private func resolveAllEmojis() async {
        guard !items.isEmpty else {
            await MainActor.run { emojiMap = [:] }
            return
        }

        var resolved: [UUID: String] = [:]
        await withTaskGroup(of: (UUID, String?).self) { group in
            for item in items {
                group.addTask {
                    let key = emojiKey(for: item)
                    if let cached = await EmojiResolver.shared.cachedEmoji(for: key) {
                        return (item.id, cached)
                    }

                    let prompt =
                        "Return a single Apple emoji that best represents this receipt item. Item: \(item.name). Category: \(item.category)."
                    let response = try? await AIService.shared.generateContent(
                        prompt: prompt,
                        systemInstruction: "Respond with a single emoji only. No words or punctuation.",
                        config: AIService.GenerationConfig(temperature: 0.2, maxOutputTokens: 8)
                    )
                    if let text = response?.text,
                        let emoji = EmojiResolver.firstEmoji(in: text)
                    {
                        await EmojiResolver.shared.setEmoji(emoji, for: key)
                        return (item.id, emoji)
                    }

                    return (item.id, nil)
                }
            }

            for await (id, emoji) in group {
                if let emoji {
                    resolved[id] = emoji
                }
            }
        }

        await MainActor.run { emojiMap = resolved }
    }

    private nonisolated func emojiKey(for item: ReceiptItem) -> String {
        "\(item.name.lowercased())|\(item.category.lowercased())"
    }
}

// MARK: - Edit Receipt View

struct EditReceiptView: View {
    @State var receipt: Receipt
    var isLocalReceipt: Bool = false
    var onSave: (Receipt) async -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    
    @State private var showImageGallery = false
    @State private var selectedImageIndex = 0
    @State private var showCurrencyPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Storage Status Section
                if isLocalReceipt {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandWarning.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "iphone")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.brandWarning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saved Locally")
                                    .font(.manrope(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                
                                Text("This receipt is only on your device")
                                    .font(.manrope(size: 12))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        
                        Button {
                            haptics.buttonPress()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                subscriptionManager.presentPaywall(trigger: .featureLocked("Cloud Sync"))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Upgrade to sync to cloud")
                                    .font(.manrope(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.brandVibrantBlue)
                        }
                    } header: {
                        Text("Storage")
                    }
                } else {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandSuccess.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "cloud.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.brandSuccess)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saved in Cloud")
                                    .font(.manrope(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                
                                Text("Synced across all your devices")
                                    .font(.manrope(size: 12))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.brandSuccess)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Storage")
                    }
                }
                
                Section("Store Info") {
                    TextField("Store Name", text: $receipt.store_name)
                    TextField("Store Address", text: $receipt.store_address)
                }

                // Receipt Images with gallery
                if !receipt.image_urls.isEmpty {
                    Section("Receipt Images") {
                        ReceiptImageRow(imageURLs: receipt.image_urls)
                    }
                }

                if !receipt.items.isEmpty {
                    Section("Items (\(receipt.items.count))") {
                        ReceiptItemsList(items: receipt.items)
                    }
                }

                Section("Details") {
                    HStack {
                        Text("Currency")
                        Spacer()
                        Button {
                            showCurrencyPicker = true
                        } label: {
                            let flag = CurrencyService.shared.getCurrencyInfo(for: receipt.currency)?.flag ?? "🌍"
                            Text("\(flag) \(receipt.currency)")
                                .foregroundStyle(Color.brandVibrantBlue)
                        }
                    }
                    
                    TextField(
                        "Amount", value: $receipt.total_amount,
                        format: .currency(code: receipt.currency)
                    ).keyboardType(.decimalPad)
                    TextField(
                        "Tax", value: $receipt.total_tax, format: .currency(code: receipt.currency)
                    ).keyboardType(.decimalPad)
                    DatePicker(
                        "Date", selection: $receipt.purchase_date, displayedComponents: .date)
                    TextField("Payment Method", text: $receipt.payment_method)
                }
                
                // Savings info
                if receipt.savings > 0 {
                    Section {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(Color.brandSuccess)
                            Text("You saved")
                                .font(.manrope(size: 14))
                            Spacer()
                            Text(formatCurrency(receipt.savings))
                                .font(.ibmPlexMono(size: 15))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(Color.brandSuccess)
                        }
                    } header: {
                        Text("Savings")
                    }
                }
            }
            .navigationTitle("Edit Receipt")
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: $receipt.currency)
                    .presentationDetents([.medium, .large])
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.buttonPress()
                        dismiss()
                    }
                    .font(.manrope(size: 16, weight: .medium))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        haptics.buttonPress()
                        Task {
                            await onSave(receipt)
                            dismiss()
                        }
                    }
                    .font(.manrope(size: 16, weight: .semibold))
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: receipt.currency)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Brand Logo View

struct BrandLogoView: View {
    let storeName: String
    let logoSearchTerm: String?
    @State private var logo: UIImage?

    var body: some View {
        Group {
            if let logo = logo {
                Image(uiImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    Color.brandAccentLight
                    Text(String(storeName.prefix(1)).uppercased())
                        .font(.instrumentSerif(size: 20))
                        .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        }
        .task {
            let query = logoSearchTerm ?? storeName
            logo = await BrandfetchService.shared.fetchLogo(for: query)
        }
    }
}

// MARK: - Storage Indicator Badge

struct StorageIndicatorBadge: View {
    let isLocal: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isLocal ? "iphone" : "cloud.fill")
                .font(.system(size: 9, weight: .medium))
            
            Text(isLocal ? "Local" : "Cloud")
                .font(.manrope(size: 9, weight: .semibold))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(isLocal ? Color.brandWarning : Color.brandSuccess)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isLocal ? Color.brandWarning.opacity(0.15) : Color.brandSuccess.opacity(0.15))
        )
    }
}
