//
//  HistoryView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-22.
//

import SwiftUI
import Supabase
import Foundation
import UIKit

// Extension to convert SwiftUI Color to UIColor
extension Color {
    func uiColor() -> UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        } else {
            // Fallback for iOS 13
            let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            var hexNumber: UInt64 = 0
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1

            // Default to a medium blue if we can't parse the color
            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                a = CGFloat(hexNumber & 0x000000ff) / 255
            }
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
    }
}

// Logo cache for storing fetched logos (thread-safe, avoids bridging Color in storage)
class LogoCache: ObservableObject {
    static let shared = LogoCache()
    
    // Store images and colors separately to avoid complex tuple bridging and SwiftUI.Color storage
    private var imageCache: [String: UIImage] = [:]
    private var colorCache: [String: [UIColor]] = [:]
    private let lock = NSLock()
    
    func getLogo(for key: String) -> (UIImage, [Color])? {
        lock.lock(); defer { lock.unlock() }
        guard let image = imageCache[key], let uiColors = colorCache[key] else { return nil }
        // Convert back to SwiftUI.Color on read
        let colors: [Color] = uiColors.map { Color($0) }
        return (image, colors)
    }
    
    func setLogo(_ logo: (UIImage, [Color]), for key: String) {
        lock.lock(); defer { lock.unlock() }
        imageCache[key] = logo.0
        // Convert SwiftUI.Color to UIColor for storage
        let uiColors: [UIColor] = logo.1.map { $0.uiColor() }
        colorCache[key] = uiColors
    }
    
    func clearCache() {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeAll()
        colorCache.removeAll()
    }
}

// Logo service has been migrated to BrandfetchService.swift
// Use BrandfetchService.shared for all logo fetching
typealias LogoService = BrandfetchService

struct HistoryView: View {
    @State private var receipts: [Receipt] = []
    @State private var isRefreshing = false
    @State private var selectedReceipt: Receipt? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var deletingReceiptId: String? = nil
    @EnvironmentObject var appState: AppState

    // Multi-selection states
    @State private var isSelectionMode = false
    @State private var selectedReceiptIds: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeletingSelected = false

    // Search and Filter States
    @State private var searchText: String = ""
    @State private var selectedDate: Date? = nil
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var filterByDateRange: Bool = false
    @State private var sortBy: SortOption = .dateNewest
    @State private var showFilterOptions: Bool = false

    // Sorting Options
    enum SortOption: String, CaseIterable, Identifiable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case storeAZ = "Store (A-Z)"
        case storeZA = "Store (Z-A)"
        case amountHigh = "Amount (Highest)"
        case amountLow = "Amount (Lowest)"
        var id: Self { self }
    }

    // Computed properties for selection mode
    var selectedReceipts: [Receipt] {
        filteredAndSortedReceipts.filter { selectedReceiptIds.contains($0.id.uuidString) }
    }
    
    var isAllSelected: Bool {
        !filteredAndSortedReceipts.isEmpty && selectedReceiptIds.count == filteredAndSortedReceipts.count
    }
    
    var isPartiallySelected: Bool {
        !selectedReceiptIds.isEmpty && selectedReceiptIds.count < filteredAndSortedReceipts.count
    }

    func fetchReceipts() async {
        // Check if we're in guest mode (using local storage)
        print("🔄 [HistoryView] Starting fetchReceipts...")
        if appState.useLocalStorage {
            print("💾 [HistoryView] Using local storage mode")
            // Get receipts from local storage
            let localReceipts = LocalStorageService.shared.getReceipts()
            print("💾 [HistoryView] Retrieved \(localReceipts.count) receipts from local storage")

            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = localReceipts
            }
            print("✅ [HistoryView] Local receipts loaded successfully")
            return
        }

        // If not in guest mode, fetch from backend API
        print("🌐 [HistoryView] Using remote Supabase mode")
        print("🔐 [HistoryView] User logged in: \(appState.isLoggedIn)")
        print("📧 [HistoryView] User email: \(appState.userEmail)")
        
        do {
            print("📡 [HistoryView] Calling supabase.fetchReceipts...")
            let fetchedReceipts = try await supabase.fetchReceipts(page: 1, limit: 1000)
            print("✅ [HistoryView] Fetched \(fetchedReceipts.count) receipts from Supabase")

            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = fetchedReceipts
            }
        } catch {
            print("❌ [HistoryView] Error fetching receipts: \(error.localizedDescription)")
            print("❌ [HistoryView] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [HistoryView] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [HistoryView] Error userInfo: \(nsError.userInfo)")
            }
        }
    }

    // Handle receipt deletion
    func handleDeleteReceipt(_ receipt: Receipt) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            // Remove the receipt from our local array
            receipts.removeAll { $0.id == receipt.id }

            // If in guest mode, also delete from local storage
            if appState.useLocalStorage {
                LocalStorageService.shared.deleteReceipt(withId: receipt.id)
            }
        }
    }

    // Handle multiple receipt deletion
    func handleDeleteSelectedReceipts() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isDeletingSelected = true
        }
        
        // Add delay to let animation play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task {
                // Delete selected receipts
                for receipt in selectedReceipts {
                    if appState.useLocalStorage {
                        LocalStorageService.shared.deleteReceipt(withId: receipt.id)
                    } else {
                        do {
                            try await supabase.deleteReceipt(id: receipt.id.uuidString)
                        } catch {
                            print("Error deleting receipt \(receipt.id): \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        // Remove from local array
                        receipts.removeAll { selectedReceiptIds.contains($0.id.uuidString) }
                        // Clear selection
                        selectedReceiptIds.removeAll()
                        isSelectionMode = false
                        isDeletingSelected = false
                    }
                }
            }
        }
    }

    // Toggle selection mode
    func toggleSelectionMode() {
        // Haptic feedback
        if appState.isHapticsEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedReceiptIds.removeAll()
            }
        }
    }

    // Toggle all receipts selection
    func toggleAllSelection() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if isAllSelected {
                selectedReceiptIds.removeAll()
            } else {
                selectedReceiptIds = Set(filteredAndSortedReceipts.map { $0.id.uuidString })
            }
        }
    }

    // Toggle individual receipt selection
    func toggleReceiptSelection(_ receipt: Receipt) {
        // Haptic feedback
        if appState.isHapticsEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            let receiptId = receipt.id.uuidString
            if selectedReceiptIds.contains(receiptId) {
                selectedReceiptIds.remove(receiptId)
            } else {
                selectedReceiptIds.insert(receiptId)
            }
        }
    }

    // Computed property for filtered and sorted receipts
    var filteredAndSortedReceipts: [Receipt] {
        var filtered = receipts

        if !searchText.isEmpty {
            filtered = filtered.filter { receipt in
                receipt.store_name.localizedCaseInsensitiveContains(searchText) ||
                receipt.receipt_name.localizedCaseInsensitiveContains(searchText) ||
                receipt.items.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) }) ||
                String(format: "%.2f", receipt.total_amount).contains(searchText)
            }
        }

        if filterByDateRange {
            if let start = startDate, let end = endDate {
                filtered = filtered.filter { receipt in
                    receipt.purchase_date >= start && receipt.purchase_date <= end
                }
            } else if let singleDate = selectedDate {
                let calendar = Calendar.current
                if let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: singleDate),
                   let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: singleDate) {
                    filtered = filtered.filter { receipt in
                        receipt.purchase_date >= startOfDay && receipt.purchase_date <= endOfDay
                    }
                }
            }
        }

        switch sortBy {
        case .dateNewest:
            filtered.sort { $0.purchase_date > $1.purchase_date }
        case .dateOldest:
            filtered.sort { $0.purchase_date < $1.purchase_date }
        case .storeAZ:
            filtered.sort { $0.store_name.localizedStandardCompare($1.store_name) == .orderedAscending }
        case .storeZA:
            filtered.sort { $0.store_name.localizedStandardCompare($1.store_name) == .orderedDescending }
        case .amountHigh:
            filtered.sort { $0.total_amount > $1.total_amount }
        case .amountLow:
            filtered.sort { $0.total_amount < $1.total_amount }
        }

        return filtered
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BackgroundGradientView()

                VStack {
                    // Selection Mode Header
                    if isSelectionMode {
                        HStack {
                            Button(action: toggleSelectionMode) {
                                Text("Cancel")
                                    .font(.instrumentSans(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button(action: toggleAllSelection) {
                                Text(isAllSelected ? "Deselect All" : "Select All")
                                    .font(.instrumentSans(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Text("\(selectedReceiptIds.count) selected")
                                .font(.instrumentSans(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Text("Delete")
                                    .font(.instrumentSans(size: 16, weight: .medium))
                                    .foregroundColor(selectedReceiptIds.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedReceiptIds.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search store, item, amount...", text: $searchText)
                            .font(.instrumentSans(size: 16))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Filter and Sort Options
                    HStack {
                        Menu {
                            Picker("Sort By", selection: $sortBy) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }

                        Spacer()

                        Button {
                            withAnimation {
                                showFilterOptions.toggle()
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        // Selection Mode Toggle
                        Button(action: toggleSelectionMode) {
                            Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelectionMode ? .blue : .secondary)
                        }
                        .scaleEffect(isSelectionMode ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelectionMode)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if showFilterOptions {
                        FilterView(
                            selectedDate: $selectedDate,
                            startDate: $startDate,
                            endDate: $endDate,
                            filterByDateRange: $filterByDateRange
                        )
                        .transition(.slide)
                    }

                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if filteredAndSortedReceipts.isEmpty {
                                EmptyStateView(message: searchText.isEmpty && !filterByDateRange ? "Your receipt history is empty." : "No receipts match your search and filter criteria.")
                                    .padding(.top, 50)
                            } else {
                                // Grid or List View (same as before, now using filteredAndSortedReceipts)
                                if geometry.size.width > 500 {
                                    receiptGridView(receipts: filteredAndSortedReceipts)
                                } else {
                                    receiptListView(receipts: filteredAndSortedReceipts)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 100) // Add bottom padding for safe area
                    }
                    .refreshable {
                        // Haptic feedback for refresh
                        if appState.isHapticsEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        isRefreshing = true
                        await fetchReceipts()
                        isRefreshing = false
                        
                        // Success feedback
                        if appState.isHapticsEnabled {
                            let notification = UINotificationFeedbackGenerator()
                            notification.notificationOccurred(.success)
                        }
                    }
                }
                .padding(.top, 10) // Adjust top padding
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt, onUpdate: { updatedReceipt in
                    // Update the receipt in our local array
                    if let index = receipts.firstIndex(where: { $0.id == updatedReceipt.id }) {
                        receipts[index] = updatedReceipt
                    }
                })
                .environmentObject(appState)
            }
            .alert("Delete Selected Receipts", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete \(selectedReceiptIds.count) Receipt\(selectedReceiptIds.count == 1 ? "" : "s")", role: .destructive) {
                    handleDeleteSelectedReceipts()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedReceiptIds.count) receipt\(selectedReceiptIds.count == 1 ? "" : "s")? This action cannot be undone.")
            }
            .onAppear {
                Task {
                    await fetchReceipts()
                }
            }
        }
    }

    private func receiptGridView(receipts: [Receipt]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)], spacing: 20) {
            ForEach(receipts) { receipt in
                EnhancedReceiptCard(
                    receipt: receipt, 
                    onDelete: handleDeleteReceipt,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedReceiptIds.contains(receipt.id.uuidString),
                    onSelectionToggle: { toggleReceiptSelection(receipt) }
                )
                .onTapGesture {
                    if isSelectionMode {
                        toggleReceiptSelection(receipt)
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            selectedReceipt = receipt
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: receipts)
    }

    private func receiptListView(receipts: [Receipt]) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(receipts) { receipt in
                EnhancedReceiptCard(
                    receipt: receipt, 
                    onDelete: handleDeleteReceipt,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedReceiptIds.contains(receipt.id.uuidString),
                    onSelectionToggle: { toggleReceiptSelection(receipt) }
                )
                .onTapGesture {
                    if isSelectionMode {
                        toggleReceiptSelection(receipt)
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            selectedReceipt = receipt
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity).combined(with: .slide)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: receipts)
    }
}

struct FilterView: View {
    @Binding var selectedDate: Date?
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var filterByDateRange: Bool

    var body: some View {
        VStack(spacing: 15) {

                VStack(alignment: .leading) {
                    Text("Select Date:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    DatePicker("Select a date", selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { newValue in selectedDate = newValue }
                    ), displayedComponents: [.date])
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .padding(.horizontal)

                    Text("Or Date Range:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 10)

                    HStack {
                        DatePicker("Start Date", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { newValue in startDate = newValue }
                        ), displayedComponents: [.date])
                        Text("to")
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { newValue in endDate = newValue }
                        ), displayedComponents: [.date])
                    }
                    .padding(.horizontal)
                }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct EnhancedReceiptCard: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]
    @State private var isLoaded = false
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    @StateObject private var currencyManager = CurrencyManager.shared
    // Callback for when deletion is complete
    var onDelete: ((Receipt) -> Void)?
    // Selection mode properties
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)?
    
    var body: some View {
        return ZStack {
            // Main card content
            ZStack(alignment: .topLeading) {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        primaryLogoColor.opacity(0.7),
                                        primaryLogoColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: shadowColor, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 5 : 3)
                    .overlay(
                        // Selection indicator
                        Group {
                            if isSelectionMode {
                                HStack {
                                    Spacer()
                                    VStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Color.blue : Color.clear)
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.blue, lineWidth: 2)
                                                )
                                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .scaleEffect(isSelected ? 1.0 : 0.5)
                                            }
                                        }
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                                        Spacer()
                                    }
                                }
                                .padding(.trailing, 12)
                            }
                        }
                    )

            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Store info with integrated logo
                    HStack(spacing: 10) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: primaryLogoColor.opacity(0.5), radius: 4, x: 0, y: 2)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(primaryLogoColor.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Text(String(receipt.store_name.prefix(1)).uppercased())
                                    .font(.spaceGrotesk(size: 20, weight: .bold))
                                    .foregroundColor(primaryLogoColor)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(receipt.store_name.capitalized)
                                .font(.instrumentSans(size: 18, weight: .semibold))
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text(receipt.receipt_name)
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Price tag
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(primaryLogoColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                            .frame(height: 32)

                        // Show total amount with savings indicator if there are savings
                        HStack(spacing: 4) {
                            Text(currencyManager.formatAmount(receipt.total_amount, currencyCode: receipt.currency))
                                .font(.spaceGrotesk(size: 20, weight: .bold))
                                .foregroundColor(receipt.savings > 0 ? .green : primaryLogoColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6) // Shrink text to fit if needed
                                .fixedSize(horizontal: false, vertical: true) // Allow horizontal shrinking

                            // Only show savings tag if savings is greater than 0
                            if receipt.savings > 0 {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryLogoColor.opacity(0.8))

                    Text(formatDate(receipt.purchase_date))
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Delete button (only show when not in selection mode)
                    if !isSelectionMode {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .opacity(isHovered ? 1 : 0.3)
                        .scaleEffect(isHovered ? 1.1 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                    }
                }
                .padding(.top, 2)

                Rectangle()
                    .fill(LinearGradient(
                        colors: [primaryLogoColor.opacity(0.3), primaryLogoColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 1)
                    .padding(.vertical, 6)

                if !receipt.items.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("ITEMS")
                                .font(.instrumentSans(size: 11, weight: .semibold))
                                .foregroundColor(secondaryLogoColor)
                                .tracking(1)

                            Spacer()

                            Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                                .font(.instrumentSans(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(receipt.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 6) {
                                        // Icon for item type
                                        if item.isDiscount {
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green)
                                        } else {
                                            Circle()
                                                .fill(logoColors[index % max(1, logoColors.count)])
                                                .frame(width: 8, height: 8)
                                        }

                                        // Item name with optional discount tag
                                        HStack(spacing: 4) {
                                            Text(item.name)
                                                .font(.instrumentSans(size: 13))
                                                .foregroundColor(.primary.opacity(0.8))
                                                .lineLimit(1)
                                                .truncationMode(.tail)

                                            // Small discount tag if needed
                                            if let _ = item.discountDescription, item.isDiscount {
                                                Text("DISCOUNT")
                                                    .font(.instrumentSans(size: 8))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.green)
                                                    )
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer(minLength: 4)

                                        // Price display
                                        HStack(spacing: 2) {
                                            // Only show strikethrough for actual discounts with originalPrice > 0
                                            if let originalPrice = item.originalPrice, originalPrice > 0, originalPrice != item.price {
                                                Text(currencyManager.formatAmount(originalPrice, currencyCode: receipt.currency))
                                                    .font(.instrumentSans(size: 10))
                                                    .foregroundColor(.secondary)
                                                    .strikethrough(true, color: .green.opacity(0.7))
                                            }

                                            Text(currencyManager.formatAmount(item.price, currencyCode: receipt.currency))
                                                .font(.instrumentSans(size: 13, weight: .medium))
                                                .foregroundColor(getItemColor(item: item, index: index))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .frame(height: 44) // Fixed height for all items
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                colorScheme == .dark
                                                ? LinearGradient(
                                                    colors: [
                                                        logoColors[index % max(1, logoColors.count)].opacity(0.2),
                                                        logoColors[index % max(1, logoColors.count)].opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                  )
                                                : LinearGradient(
                                                    colors: [
                                                        logoColors[index % max(1, logoColors.count)].opacity(0.1),
                                                        logoColors[index % max(1, logoColors.count)].opacity(0.05)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                  )
                                            )
                                            .shadow(
                                                color: logoColors[index % max(1, logoColors.count)].opacity(0.1),
                                                radius: 3,
                                                x: 0,
                                                y: 1
                                            )
                                    )
                                }

                                if receipt.items.count > 3 {
                                    HStack {
                                        Text("+\(receipt.items.count - 3) more")
                                            .font(.instrumentSans(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .frame(height: 44) // Match height with other items
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                colorScheme == .dark
                                                ? LinearGradient(
                                                    colors: [Color.secondary.opacity(0.15), Color.secondary.opacity(0.08)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                  )
                                                : LinearGradient(
                                                    colors: [Color.secondary.opacity(0.12), Color.secondary.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                  )
                                            )
                                            .shadow(
                                                color: Color.secondary.opacity(0.1),
                                                radius: 3,
                                                x: 0,
                                                y: 1
                                            )
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .opacity(isDeleting ? 0 : 1) // Fade out when deleting
        }
        }
        .frame(height: 200)
        .scaleEffect(isDeleting ? 0.8 : (isHovered ? 1.02 : 1))
        .opacity(isLoaded ? (isDeleting ? 0 : 1) : 0)
        .offset(y: isLoaded ? (isDeleting ? 50 : 0) : 20)

        // Let parent handle taps for opening details or selection
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            loadLogo()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)
                .delay(Double.random(in: 0.1...0.3))) {
                isLoaded = true
            }
        }
        
        .alert("Delete Receipt", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
        } message: {
            Text("Are you sure you want to delete this receipt from \(receipt.store_name)? This action cannot be undone.")
        }
    }

    @EnvironmentObject var appState: AppState

    private func deleteReceipt() {
        // Haptic feedback
        if appState.isHapticsEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isDeleting = true
        }

        // Add a slight delay to let the animation play before actually deleting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                // Check if we're in guest mode (using local storage)
                if self.appState.useLocalStorage {
                    // Delete from local storage
                    LocalStorageService.shared.deleteReceipt(withId: receipt.id)

                    // Call the onDelete callback to update the UI
                    await MainActor.run {
                        onDelete?(receipt)
                    }
                    return
                }

                // If not in guest mode, delete via backend API
                do {
                    try await supabase.deleteReceipt(id: receipt.id.uuidString)
                    print("Receipt deleted successfully: \(receipt.id)")
                    // Call the onDelete callback to update the UI
                    await MainActor.run {
                        onDelete?(receipt)
                    }
                } catch {
                    print("Error deleting receipt: \(error.localizedDescription)")
                    // Revert animation if delete failed
                    await MainActor.run {
                        withAnimation {
                            isDeleting = false
                        }
                    }
                }
            }
        }
    }

    private var primaryLogoColor: Color {
        if appState.usePlainReceiptColors { return Color.blue }
        return logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }

    private var secondaryLogoColor: Color {
        if appState.usePlainReceiptColors { return Color.blue.opacity(0.8) }
        return logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }

    private var backgroundGradient: LinearGradient {
        if appState.usePlainReceiptColors {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.black.opacity(0.8) : Color.white,
                    colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color(UIColor.systemBackground).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        colorScheme == .dark
        ? primaryLogoColor.opacity(0.3)
        : primaryLogoColor.opacity(0.2)
    }

    private func getItemColor(item: ReceiptItem, index: Int) -> Color {
        if item.isDiscount {
            return .green
        } else if item.price == 0 {
            return .green // Free items
        } else if let originalPrice = item.originalPrice, originalPrice > item.price {
            return .green // Discounted items
        } else {
            return logoColors[index % max(1, logoColors.count)]
        }
    }

    private func loadLogo() {
        // Use the enhanced logo fetching method unless plain colors are enabled
        if appState.usePlainReceiptColors {
            logoImage = nil
            logoColors = [Color.blue, Color.blue.opacity(0.8)]
        } else {
            Task {
                let (image, colors) = await LogoService.shared.fetchLogoForReceipt(receipt)
                await MainActor.run {
                    logoImage = image
                    logoColors = colors
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Preview
#Preview {
    NavigationView {
        HistoryView()
    }
} 
