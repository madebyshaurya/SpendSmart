import Combine
import PhotosUI
import SwiftUI

// MARK: - Receipts View Model

@MainActor
class ReceiptsViewModel: ObservableObject {
    enum DateFilterMode: String, CaseIterable, Identifiable {
        case any = "Any Date"
        case exact = "Specific Day"
        case range = "Date Range"

        var id: String { rawValue }
    }

    enum TotalFilterMode: String, CaseIterable, Identifiable {
        case any = "Any Amount"
        case exact = "Exact Amount"
        case range = "Amount Range"

        var id: String { rawValue }
    }
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Newest First"
        case dateOldest = "Oldest First"
        case amountHigh = "Highest Amount"
        case amountLow = "Lowest Amount"
        case storeName = "Store Name"
        
        var icon: String {
            switch self {
            case .dateNewest: return "arrow.down.circle"
            case .dateOldest: return "arrow.up.circle"
            case .amountHigh: return "dollarsign.arrow.circlepath"
            case .amountLow: return "dollarsign.arrow.circlepath"
            case .storeName: return "textformat.abc"
            }
        }
    }
    
    enum SearchScope: String, CaseIterable {
        case all = "All"
        case store = "Store"
        case items = "Items"
        case address = "Address"
    }

    @Published var receipts: [Receipt] = []
    @Published var localReceipts: [Receipt] = []
    @Published var cloudReceipts: [Receipt] = []
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var searchScope: SearchScope = .all
    @Published var debouncedSearchText = ""
    @Published var selectedItem: PhotosPickerItem? {
        didSet { if let item = selectedItem { Task { await upload(item: item) } } }
    }
    @Published var editingReceipt: Receipt?
    @Published var advancedStoreName: String = ""
    @Published var advancedLocation: String = ""
    @Published var advancedItemQuery: String = ""
    @Published var dateFilterMode: DateFilterMode = .any
    @Published var dateExact: Date = Date()
    @Published var dateStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var dateEnd: Date = Date()
    @Published var totalFilterMode: TotalFilterMode = .any
    @Published var totalExactInput: String = ""
    @Published var totalMinInput: String = ""
    @Published var totalMaxInput: String = ""
    @Published var sortOption: SortOption = .dateNewest

    private let supabase = SupabaseManager.shared
    private let localStorage = LocalReceiptStorage.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search text by 300ms for performance with large lists
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedSearchText)
    }

    var allReceipts: [Receipt] {
        var combined: [Receipt] = []
        var seenIds: Set<UUID> = []
        
        for receipt in localReceipts {
            if !seenIds.contains(receipt.id) {
                combined.append(receipt)
                seenIds.insert(receipt.id)
            }
        }
        
        for receipt in cloudReceipts {
            if !seenIds.contains(receipt.id) {
                combined.append(receipt)
                seenIds.insert(receipt.id)
            }
        }
        
        return sortReceipts(combined)
    }
    
    private func sortReceipts(_ receipts: [Receipt]) -> [Receipt] {
        switch sortOption {
        case .dateNewest:
            return receipts.sorted { $0.purchase_date > $1.purchase_date }
        case .dateOldest:
            return receipts.sorted { $0.purchase_date < $1.purchase_date }
        case .amountHigh:
            return receipts.sorted { $0.total_amount > $1.total_amount }
        case .amountLow:
            return receipts.sorted { $0.total_amount < $1.total_amount }
        case .storeName:
            return receipts.sorted { $0.store_name.lowercased() < $1.store_name.lowercased() }
        }
    }

    var filteredReceipts: [Receipt] {
        allReceipts.filter { receipt in
            matchesBasicSearch(receipt) && matchesAdvancedFilters(receipt)
        }
    }

    var isAdvancedFilterActive: Bool {
        let hasStore = !advancedStoreName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLocation = !advancedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasItems = !advancedItemQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTotals = totalFilterMode != .any
            || !totalExactInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !totalMinInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !totalMaxInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDates = dateFilterMode != .any
        return hasStore || hasLocation || hasItems || hasTotals || hasDates
    }
    
    var isUsingPlusOnlyFilters: Bool {
        let hasDateFilter = dateFilterMode != .any
        let hasAmountFilter = totalFilterMode != .any
        return hasDateFilter || hasAmountFilter
    }
    
    var recentStoreNames: [String] {
        let stores = allReceipts.map { $0.store_name }
        let counted = Dictionary(grouping: stores, by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { $0.key }
        return counted
    }
    
    var popularCategories: [String] {
        let categories = allReceipts
            .flatMap { $0.items }
            .map { $0.category }
            .filter { !$0.isEmpty }
        let counted = Dictionary(grouping: categories, by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { $0.key }
        return counted
    }
    
    func isLocalReceipt(_ receipt: Receipt) -> Bool {
        localReceipts.contains { $0.id == receipt.id }
    }

    func loadReceipts() async {
        isLoading = true
        errorMessage = nil
        
        localReceipts = localStorage.getAllReceipts()
        
        do {
            cloudReceipts = try await supabase.fetchReceipts(page: 1, limit: 100)
        } catch {
            print("Failed to load cloud receipts: \(error.localizedDescription)")
        }
        
        receipts = allReceipts
        isLoading = false
    }

    func upload(item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                let img = UIImage(data: data)
            else { throw URLError(.badServerResponse) }

            let aiTask = Task { try await BackendAPIService.shared.processReceipt(images: [img]) }
            let uploadTask = Task { try await BackendAPIService.shared.uploadImages([img]) }

            let res = try await aiTask.value
            let uploadRes = try await uploadTask.value

            let imageUrls: [String] = uploadRes.images.compactMap { $0.success ? $0.url : nil }

            if res.isValid {
                let receipt = Receipt(
                    id: UUID(),
                    user_id: UUID(),
                    image_urls: imageUrls,
                    total_amount: res.total_amount ?? 0,
                    items: res.items?.map {
                        ReceiptItem(
                            id: UUID(), name: $0.name, price: $0.price, category: $0.category)
                    } ?? [],
                    store_name: res.store_name ?? "Unknown Store",
                    store_address: res.store_address ?? "Unknown Address",
                    receipt_name: res.receipt_name ?? res.store_name ?? "Receipt",
                    purchase_date: PurchaseDateParser.parse(res.purchase_date) ?? Date(),
                    currency: res.currency ?? "USD",
                    payment_method: res.payment_method ?? "Unknown",
                    total_tax: res.total_tax ?? 0,
                    logo_search_term: res.logo_search_term
                )
                _ = try await supabase.createReceipt(receipt)
            } else {
                errorMessage = res.message ?? "Invalid receipt"
            }
            await loadReceipts()
        } catch { errorMessage = "Upload failed: \(error.localizedDescription)" }
        isProcessing = false
        selectedItem = nil
    }

    func updateReceipt(_ receipt: Receipt) async {
        if isLocalReceipt(receipt) {
            localStorage.saveReceipt(receipt)
            if let idx = localReceipts.firstIndex(where: { $0.id == receipt.id }) {
                localReceipts[idx] = receipt
            }
        } else {
            if let idx = cloudReceipts.firstIndex(where: { $0.id == receipt.id }) {
                cloudReceipts[idx] = receipt
            }
            do {
                _ = try await supabase.updateReceipt(receipt)
            } catch {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                await loadReceipts()
            }
        }
        
        receipts = allReceipts
    }

    func deleteReceipt(at offsets: IndexSet) {
        let targets = offsets.map { filteredReceipts[$0] }

        Task {
            for r in targets {
                if isLocalReceipt(r) {
                    localStorage.deleteReceipt(id: r.id)
                    await MainActor.run {
                        localReceipts.removeAll { $0.id == r.id }
                    }
                } else {
                    do {
                        try await supabase.deleteReceipt(id: r.id.uuidString)
                        await MainActor.run {
                            cloudReceipts.removeAll { $0.id == r.id }
                        }
                    } catch {
                        print("Error deleting receipt: \(error)")
                    }
                }
            }
            
            await MainActor.run {
                receipts = allReceipts
            }
        }
    }

    func resetAdvancedFilters() {
        advancedStoreName = ""
        advancedLocation = ""
        advancedItemQuery = ""
        dateFilterMode = .any
        dateExact = Date()
        dateStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        dateEnd = Date()
        totalFilterMode = .any
        totalExactInput = ""
        totalMinInput = ""
        totalMaxInput = ""
    }

    private func matchesBasicSearch(_ receipt: Receipt) -> Bool {
        let term = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let lower = term.lowercased()
        
        switch searchScope {
        case .all:
            if receipt.store_name.lowercased().contains(lower) { return true }
            if receipt.receipt_name.lowercased().contains(lower) { return true }
            if String(format: "%.2f", receipt.total_amount).contains(lower) { return true }
            if receipt.store_address.lowercased().contains(lower) { return true }
            if receipt.items.contains(where: { $0.name.lowercased().contains(lower) || $0.category.lowercased().contains(lower) }) { return true }
            return false
            
        case .store:
            if receipt.store_name.lowercased().contains(lower) { return true }
            if receipt.receipt_name.lowercased().contains(lower) { return true }
            return false
            
        case .items:
            return receipt.items.contains { $0.name.lowercased().contains(lower) || $0.category.lowercased().contains(lower) }
            
        case .address:
            return receipt.store_address.lowercased().contains(lower)
        }
    }

    private func matchesAdvancedFilters(_ receipt: Receipt) -> Bool {
        let storeQuery = advancedStoreName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !storeQuery.isEmpty {
            let storeName = receipt.store_name.lowercased()
            let receiptName = receipt.receipt_name.lowercased()
            if !storeName.contains(storeQuery) && !receiptName.contains(storeQuery) {
                return false
            }
        }

        let locationQuery = advancedLocation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !locationQuery.isEmpty {
            let address = receipt.store_address.lowercased()
            if !address.contains(locationQuery) {
                return false
            }
        }

        let itemQuery = advancedItemQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !itemQuery.isEmpty {
            let matchesItem = receipt.items.contains { item in
                item.name.lowercased().contains(itemQuery)
                    || item.category.lowercased().contains(itemQuery)
            }
            if !matchesItem {
                return false
            }
        }

        switch dateFilterMode {
        case .any:
            break
        case .exact:
            if !calendar.isDate(receipt.purchase_date, inSameDayAs: dateExact) {
                return false
            }
        case .range:
            let (start, end) = normalizedDateRange()
            if receipt.purchase_date < start || receipt.purchase_date > end {
                return false
            }
        }

        switch totalFilterMode {
        case .any:
            break
        case .exact:
            guard let exact = parsedAmount(from: totalExactInput) else { return false }
            if abs(receipt.total_amount - exact) > 0.01 { return false }
        case .range:
            let minVal = parsedAmount(from: totalMinInput) ?? 0
            let maxVal = parsedAmount(from: totalMaxInput) ?? Double.greatestFiniteMagnitude
            if receipt.total_amount < minVal || receipt.total_amount > maxVal {
                return false
            }
        }

        return true
    }

    private func normalizedDateRange() -> (Date, Date) {
        let startDay = calendar.startOfDay(for: dateStart)
        let endDay = calendar.startOfDay(for: dateEnd)
        if startDay <= endDay {
            let inclusiveEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endDay)
                ?? endDay
            return (startDay, inclusiveEnd)
        } else {
            let inclusiveEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDay)
                ?? startDay
            return (endDay, inclusiveEnd)
        }
    }

    private func parsedAmount(from text: String) -> Double? {
        let filtered = text.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty else { return nil }
        return Double(filtered)
    }
}
