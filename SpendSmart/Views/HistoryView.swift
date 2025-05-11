//
//  HistoryView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-22.
//

import SwiftUI
import Supabase

// Logo cache to prevent unnecessary API calls
class LogoCache: ObservableObject {
    static let shared = LogoCache()
    @Published var logoCache: [String: (image: UIImage, colors: [Color])] = [:]
}

// API client for Logo.dev
class LogoService {
    static let shared = LogoService()
    private let publicKey = "pk_EB5BNaRARdeXj64ti60xGQ"

    // Default colors to use when no logo is available
    private let defaultColors: [Color] = [.gray, Color(hex: "555555"), Color(hex: "777777")]

    func fetchLogo(for storeName: String) async -> (UIImage?, [Color]) {
        // Handle empty store names
        guard !storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, defaultColors)
        }

        // Check cache first
        if let cached = LogoCache.shared.logoCache[storeName.lowercased()] {
            return (cached.image, cached.colors)
        }

        let formattedName = storeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? storeName
        let urlString = "https://api.logo.dev/search?q=\(formattedName)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for logo fetch: \(urlString)")
            return (nil, defaultColors)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // Set a reasonable timeout

        // Implement retry logic
        let maxRetries = 1
        var retryCount = 0

        while retryCount <= maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Error: Not an HTTP response")
                    retryCount += 1
                    if retryCount > maxRetries {
                        return (nil, defaultColors)
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 second before retry
                    continue
                }

                if httpResponse.statusCode != 200 {
                    print("Error response: HTTP \(httpResponse.statusCode)")
                    retryCount += 1
                    if retryCount > maxRetries {
                        return (nil, defaultColors)
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 second before retry
                    continue
                }

                // Decode JSON as an array of dictionaries
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

                    guard let array = jsonArray, !array.isEmpty,
                          let firstResult = array.first,
                          let logoUrlString = firstResult["logo_url"] as? String,
                          let logoUrl = URL(string: logoUrlString) else {
                        print("Failed to parse logo JSON response")
                        return (nil, defaultColors)
                    }

                    // Fetch the logo image with timeout
                    let logoRequest = URLRequest(url: logoUrl, timeoutInterval: 10)
                    let (imageData, _) = try await URLSession.shared.data(for: logoRequest)

                    guard let image = UIImage(data: imageData) else {
                        print("Failed to create image from data")
                        return (nil, defaultColors)
                    }

                    let colors = image.dominantColors(count: 3)
                    let finalColors = colors.isEmpty ? defaultColors : colors

                    // Cache the result on the main thread
                    await MainActor.run {
                        LogoCache.shared.logoCache[storeName.lowercased()] = (image, finalColors)
                    }

                    return (image, finalColors)
                } catch {
                    print("JSON parsing error: \(error)")
                    retryCount += 1
                    if retryCount > maxRetries {
                        return (nil, defaultColors)
                    }
                    continue
                }
            } catch {
                print("Network error fetching logo: \(error)")
                retryCount += 1
                if retryCount > maxRetries {
                    return (nil, defaultColors)
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 second before retry
            }
        }

        return (nil, defaultColors)
    }
}

struct HistoryView: View {
    @State private var receipts: [Receipt] = []
    @State private var isRefreshing = false
    @State private var selectedReceipt: Receipt? = nil
    @StateObject private var logoCache = LogoCache.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var deletingReceiptId: String? = nil
    @EnvironmentObject var appState: AppState

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

    func fetchReceipts() async {
        // Check if we're in guest mode (using local storage)
        if appState.useLocalStorage {
            // Get receipts from local storage
            let localReceipts = LocalStorageService.shared.getReceipts()

            // Pre-fetch logos for receipts
            for receipt in localReceipts {
                Task {
                    _ = await LogoService.shared.fetchLogo(for: receipt.store_name)
                }
            }

            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = localReceipts
            }
            return
        }

        // If not in guest mode, fetch from Supabase
        do {
            let response = try await supabase
                .from("receipts")
                .select()
                .execute()

            // Debug: Print fetched JSON data
            print("Fetched Data: \(String(data: response.data, encoding: .utf8) ?? "No Data")")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }

            let fetchedReceipts = try decoder.decode([Receipt].self, from: response.data)
            print("Decoded Receipts: \(fetchedReceipts.count)")

            // Optionally pre-fetch logos for receipts here
            for receipt in fetchedReceipts {
                Task {
                    _ = await LogoService.shared.fetchLogo(for: receipt.store_name)
                }
            }

            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = fetchedReceipts
            }
        } catch {
            print("Error fetching receipts: \(error.localizedDescription)")
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
                        VStack(spacing: 20) {
                            if filteredAndSortedReceipts.isEmpty {
                                EmptyStateView(message: searchText.isEmpty && !filterByDateRange ? "Your receipt history is empty." : "No receipts match your search and filter criteria.")
                            } else {
                                // Grid or List View (same as before, now using filteredAndSortedReceipts)
                                if geometry.size.width > 500 {
                                    receiptGridView(receipts: filteredAndSortedReceipts)
                                } else {
                                    receiptListView(receipts: filteredAndSortedReceipts)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        isRefreshing = true
                        await fetchReceipts()
                        isRefreshing = false
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
                EnhancedReceiptCard(receipt: receipt, onDelete: handleDeleteReceipt)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            selectedReceipt = receipt
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
                EnhancedReceiptCard(receipt: receipt, onDelete: handleDeleteReceipt)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            selectedReceipt = receipt
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
            Toggle("Filter by Date", isOn: $filterByDateRange)
                .padding(.horizontal)

            if filterByDateRange {
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
    // Callback for when deletion is complete
    var onDelete: ((Receipt) -> Void)?

    var body: some View {
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
                            lineWidth: 1
                        )
                )
                .shadow(color: shadowColor, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 5 : 3)

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
                            Text("$\(receipt.total_amount, specifier: "%.2f")")
                                .font(.spaceGrotesk(size: 20, weight: .bold))
                                .foregroundColor(receipt.savings > 0 ? .green : primaryLogoColor)

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

                    // Delete button
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
                                                Text("$\(originalPrice, specifier: "%.2f")")
                                                    .font(.instrumentSans(size: 10))
                                                    .foregroundColor(.secondary)
                                                    .strikethrough(true, color: .green.opacity(0.7))
                                            }

                                            Text("$\(item.price, specifier: "%.2f")")
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
        .frame(height: 200)
        .scaleEffect(isDeleting ? 0.8 : (isHovered ? 1.02 : 1))
        .opacity(isLoaded ? (isDeleting ? 0 : 1) : 0)
        .offset(y: isLoaded ? (isDeleting ? 50 : 0) : 20)
        .onAppear {
            loadLogo()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)
                .delay(Double.random(in: 0.1...0.3))) {
                isLoaded = true
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
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

                // If not in guest mode, delete from Supabase
                do {
                    // Delete from Supabase
                    let response = try await supabase
                        .from("receipts")
                        .delete()
                        .eq("id", value: receipt.id)
                        .execute()

                    // Check if delete was successful
                    if response.status == 200 || response.status == 204 {
                        print("Receipt deleted successfully: \(receipt.id)")
                        // Call the onDelete callback to update the UI
                        await MainActor.run {
                            onDelete?(receipt)
                        }
                    } else {
                        print("Failed to delete receipt: \(response.status)")
                        // Revert animation if delete failed
                        await MainActor.run {
                            withAnimation {
                                isDeleting = false
                            }
                        }
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
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }

    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }

    private var backgroundGradient: some ShapeStyle {
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
        Task {
            let (image, colors) = await LogoService.shared.fetchLogo(for: receipt.store_name)
            await MainActor.run {
                logoImage = image
                logoColors = colors
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

struct IconDetailView: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
            }

            Text(detail)
                .font(.instrumentSans(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ItemCard: View {
    let item: ReceiptItem
    let logoColors: [Color]
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 40, height: 40)

                    if item.isDiscount {
                        // Special icon for discounts
                        Image(systemName: "tag.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.green)
                    } else if let iconName = categoryIcon(for: item.category) {
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(getLogoColor(at: index % logoColors.count))
                    } else {
                        Text(String(item.category.prefix(1)).uppercased())
                            .font(.spaceGrotesk(size: 18, weight: .bold))
                            .foregroundColor(getLogoColor(at: index % logoColors.count))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.instrumentSans(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    if let discountDescription = item.discountDescription {
                        Text(discountDescription)
                            .font(.instrumentSans(size: 14, weight: .medium))
                            .foregroundColor(item.isDiscount ? .green : .secondary)
                    } else {
                        Text(item.category)
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Price display with original price if available
                VStack(alignment: .trailing, spacing: 2) {
                    // Only show strikethrough for actual discounts with originalPrice > 0
                    if let originalPrice = item.originalPrice, originalPrice > 0, originalPrice != item.price {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.spaceGrotesk(size: 14))
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .green.opacity(0.7))
                    }

                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.spaceGrotesk(size: 18, weight: .bold))
                        .foregroundColor(priceColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                .shadow(
                    color: getLogoColor(at: index % logoColors.count).opacity(isHovered ? 0.15 : 0.05),
                    radius: isHovered ? 8 : 4,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark
        ? getLogoColor(at: index % logoColors.count).opacity(0.15)
        : getLogoColor(at: index % logoColors.count).opacity(0.1)
    }

    private func getLogoColor(at index: Int) -> Color {
        guard index < logoColors.count, !logoColors.isEmpty else {
            return colorScheme == .dark ? .white : .black
        }
        return logoColors[index]
    }

    private var priceColor: Color {
        if item.isDiscount {
            return .green
        } else if item.price == 0 {
            return .green // Free items
        } else if let originalPrice = item.originalPrice, originalPrice > item.price {
            return .green // Discounted items
        } else {
            return getLogoColor(at: index % logoColors.count)
        }
    }

    private func categoryIcon(for category: String) -> String? {
        let normalized = category.lowercased()
        if normalized.contains("food") || normalized.contains("grocery") {
            return "cart.fill"
        } else if normalized.contains("electronics") || normalized.contains("tech") {
            return "laptopcomputer"
        } else if normalized.contains("clothing") || normalized.contains("apparel") {
            return "tshirt.fill"
        } else if normalized.contains("restaurant") || normalized.contains("dining") {
            return "fork.knife"
        } else if normalized.contains("transport") || normalized.contains("travel") {
            return "car.fill"
        } else if normalized.contains("entertainment") {
            return "film.fill"
        } else if normalized.contains("health") || normalized.contains("medical") {
            return "cross.fill"
        } else {
            return nil
        }
    }
}

// Preview
#Preview {
    NavigationView {
        HistoryView()
    }
}
