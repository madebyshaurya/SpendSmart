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

// Logo cache to prevent unnecessary API calls
class LogoCache: ObservableObject {
    static let shared = LogoCache()
    @Published var logoCache: [String: (image: UIImage?, colors: [Color])] = [:]
    @Published var failedAttempts: [String: Date] = [:] // Track failed attempts with timestamps
    @Published var storeNameMappings: [String: String] = [:] // Map variations of store names to canonical names

    // Time before retrying a failed logo fetch (24 hours)
    let retryInterval: TimeInterval = 86400

    // UserDefaults keys
    private let logoCacheKey = "logo_cache_mappings"

    init() {
        loadCacheMappings()
    }

    // Save cache mappings to UserDefaults
    func saveCacheMappings() {
        let mappings = storeNameMappings
        UserDefaults.standard.set(mappings, forKey: logoCacheKey)
    }

    // Load cache mappings from UserDefaults
    func loadCacheMappings() {
        if let mappings = UserDefaults.standard.dictionary(forKey: logoCacheKey) as? [String: String] {
            storeNameMappings = mappings
        }
    }

    // Normalize store name for consistent caching with enhanced cleaning
    func normalizeStoreName(_ name: String) -> String {
        let normalizedName = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'s", with: "s")  // Remove apostrophes in possessives
            .replacingOccurrences(of: "&", with: "and") // Replace & with and
            .replacingOccurrences(of: "#\\d+", with: "", options: .regularExpression) // Remove store numbers
            .replacingOccurrences(of: "store", with: "") // Remove "store" word
            .replacingOccurrences(of: "market", with: "") // Remove "market" word
            .replacingOccurrences(of: "shop", with: "") // Remove "shop" word
            .replacingOccurrences(of: "restaurant", with: "") // Remove "restaurant" word
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) // Normalize whitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if we have a mapping for this name variation
        if let mappedName = storeNameMappings[normalizedName] {
            return mappedName
        }

        return normalizedName
    }

    // Generate a consistent cache key for a receipt
    func generateCacheKey(for receipt: Receipt) -> String {
        // Prioritize logo_search_term if available, otherwise use store_name
        let searchTerm = receipt.logo_search_term?.trimmingCharacters(in: .whitespacesAndNewlines) ?? receipt.store_name
        return normalizeStoreName(searchTerm)
    }

    // Generate a consistent cache key for a store location
    func generateCacheKey(for storeLocation: StoreLocation) -> String {
        return normalizeStoreName(storeLocation.logoSearchTerm)
    }

    // Add a mapping between name variations
    func addNameMapping(from variation: String, to canonical: String) {
        let normalizedVariation = variation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCanonical = canonical.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        storeNameMappings[normalizedVariation] = normalizedCanonical
        saveCacheMappings()
    }

    func shouldAttemptFetch(for storeName: String) -> Bool {
        let key = normalizeStoreName(storeName)
        // If we have a failed attempt, check if enough time has passed to retry
        if let failedDate = failedAttempts[key] {
            return Date().timeIntervalSince(failedDate) > retryInterval
        }
        return true
    }

    // Clean up old cache entries and failed attempts
    func cleanupCache() {
        let now = Date()
        let cleanupInterval: TimeInterval = 604800 // 7 days

        // Remove old failed attempts
        failedAttempts = failedAttempts.filter { _, date in
            now.timeIntervalSince(date) < cleanupInterval
        }

        // Optionally remove very old cache entries (uncomment if needed)
        // logoCache = logoCache.filter { key, _ in
        //     // Keep entries that have been accessed recently or are for common stores
        //     return true // For now, keep all cached logos
        // }

        print("🧹 Cache cleanup completed. Failed attempts: \(failedAttempts.count), Cached logos: \(logoCache.count)")
    }
}

// API client for Logo.dev
class LogoService {
    static let shared = LogoService()
    private let publicKey = "pk_EB5BNaRARdeXj64ti60xGQ"

    // Common store logos - hardcoded for reliability
    private let knownStoreLogos: [String: (UIImage, [Color])] = [:]
    // These would be populated with actual store logos in a real implementation
    // For now, we'll rely on the API but with better fallbacks

    // Store name corrections for common misspellings or variations
    private let storeNameCorrections: [String: String] = [
        "walmart": "walmart",
        "wal-mart": "walmart",
        "wal mart": "walmart",
        "target": "target",
        "costco": "costco",
        "costco wholesale": "costco",
        "amazon": "amazon",
        "amazon.com": "amazon",
        "starbucks": "starbucks",
        "mcdonalds": "mcdonalds",
        "mcdonald's": "mcdonalds",
        "safeway": "safeway",
        "kroger": "kroger",
        "whole foods": "whole foods market",
        "whole foods market": "whole foods market",
        "trader joe's": "trader joes",
        "trader joes": "trader joes",
        "best buy": "best buy",
        "home depot": "home depot",
        "the home depot": "home depot",
        "lowes": "lowes",
        "lowe's": "lowes",
        "cvs": "cvs",
        "cvs pharmacy": "cvs",
        "walgreens": "walgreens",
        "subway": "subway",
        "dunkin": "dunkin",
        "dunkin donuts": "dunkin",
        "7-eleven": "7-eleven",
        "7 eleven": "7-eleven",
        "shell": "shell",
        "exxon": "exxon",
        "bp": "bp",
        "chevron": "chevron"
    ]

    // Default colors to use when no logo is available
    private let defaultColors: [Color] = [.blue, Color(hex: "3B82F6"), Color(hex: "1D4ED8")]

    // Store category colors
    private let categoryColors: [String: [Color]] = [
        "grocery": [.green, Color(hex: "22C55E"), Color(hex: "16A34A")],
        "restaurant": [.red, Color(hex: "EF4444"), Color(hex: "DC2626")],
        "retail": [.blue, Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
        "electronics": [.purple, Color(hex: "A855F7"), Color(hex: "7E22CE")],
        "gas": [.orange, Color(hex: "F97316"), Color(hex: "EA580C")],
        "travel": [.teal, Color(hex: "14B8A6"), Color(hex: "0D9488")],
        "entertainment": [.pink, Color(hex: "EC4899"), Color(hex: "DB2777")]
    ]

    func fetchLogo(for storeName: String) async -> (UIImage?, [Color]) {
        // Handle empty store names
        guard !storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, defaultColors)
        }

        let cache = LogoCache.shared
        let normalizedName = cache.normalizeStoreName(storeName)

        print("🔍 Fetching logo for: '\(storeName)' -> normalized: '\(normalizedName)'")

        // Check for known store name corrections
        if let correctedName = checkForKnownStore(normalizedName) {
            print("✅ Found correction: '\(normalizedName)' -> '\(correctedName)'")
            // Add mapping for future reference on main thread
            await MainActor.run {
                cache.addNameMapping(from: normalizedName, to: correctedName)
            }

            // Check if we have the corrected name in cache
            if let cached = cache.logoCache[correctedName] {
                print("📦 Using cached logo for corrected name: '\(correctedName)'")
                return (cached.image, cached.colors)
            }
        }

        // Check cache first
        if let cached = cache.logoCache[normalizedName] {
            return (cached.image, cached.colors)
        }

        // Check if we should attempt to fetch (not a recent failure)
        if !cache.shouldAttemptFetch(for: normalizedName) {
            print("Skipping logo fetch for \(storeName) due to recent failure")
            return (nil, getCategoryColors(for: storeName))
        }

        // Try to fetch from API
        return await fetchLogoFromAPI(storeName: storeName, normalizedName: normalizedName)
    }

    private func checkForKnownStore(_ normalizedName: String) -> String? {
        // Check for exact matches first
        if let correctedName = storeNameCorrections[normalizedName] {
            return correctedName
        }

        // Check for partial matches
        for (key, value) in storeNameCorrections {
            if normalizedName.contains(key) {
                return value
            }
        }

        return nil
    }

    // Made public so it can be accessed from MapMarkerView
    func getCategoryColors(for storeName: String) -> [Color] {
        let lowercaseName = storeName.lowercased()

        // Try to determine store category from name
        if lowercaseName.contains("grocery") || lowercaseName.contains("market") ||
           lowercaseName.contains("food") || lowercaseName.contains("supermarket") {
            return categoryColors["grocery"] ?? defaultColors
        } else if lowercaseName.contains("restaurant") || lowercaseName.contains("cafe") ||
                  lowercaseName.contains("bar") || lowercaseName.contains("grill") {
            return categoryColors["restaurant"] ?? defaultColors
        } else if lowercaseName.contains("electronics") || lowercaseName.contains("tech") {
            return categoryColors["electronics"] ?? defaultColors
        } else if lowercaseName.contains("gas") || lowercaseName.contains("fuel") ||
                  lowercaseName.contains("petrol") {
            return categoryColors["gas"] ?? defaultColors
        } else if lowercaseName.contains("travel") || lowercaseName.contains("hotel") ||
                  lowercaseName.contains("air") {
            return categoryColors["travel"] ?? defaultColors
        } else if lowercaseName.contains("entertainment") || lowercaseName.contains("cinema") ||
                  lowercaseName.contains("theater") {
            return categoryColors["entertainment"] ?? defaultColors
        }

        return defaultColors
    }

    private func fetchLogoFromAPI(storeName: String, normalizedName: String) async -> (UIImage?, [Color]) {
        let formattedName = storeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? storeName
        let urlString = "https://api.logo.dev/search?q=\(formattedName)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for logo fetch: \(urlString)")
            cacheFailedAttempt(for: normalizedName)
            return (nil, getCategoryColors(for: storeName))
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30 // Increased timeout to 30 seconds

        // Implement retry logic
        let maxRetries = 2 // Increased max retries
        var retryCount = 0

        while retryCount <= maxRetries {
            do {
                // Create a task with a timeout
                let task = Task {
                    try await URLSession.shared.data(for: request)
                }

                // Wait for the task with a timeout
                let (data, response) = try await task.value

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Error: Not an HTTP response")
                    retryCount += 1
                    if retryCount > maxRetries {
                        cacheFailedAttempt(for: normalizedName)
                        return (nil, defaultColors)
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                    continue
                }

                if httpResponse.statusCode != 200 {
                    print("Error response: HTTP \(httpResponse.statusCode)")
                    retryCount += 1
                    if retryCount > maxRetries {
                        cacheFailedAttempt(for: normalizedName)
                        return (nil, defaultColors)
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
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
                        cacheFailedAttempt(for: normalizedName)
                        return (nil, defaultColors)
                    }

                    // Fetch the logo image with increased timeout
                    let logoRequest = URLRequest(url: logoUrl, timeoutInterval: 20)

                    do {
                        let logoTask = Task {
                            try await URLSession.shared.data(for: logoRequest)
                        }

                        let (imageData, _) = try await logoTask.value

                        guard let image = UIImage(data: imageData) else {
                            print("Failed to create image from data")
                            cacheFailedAttempt(for: normalizedName)
                            return (nil, defaultColors)
                        }

                        // Validate the logo before caching
                        guard validateLogo(image: image, for: storeName) else {
                            print("❌ Logo validation failed for: \(storeName)")
                            cacheFailedAttempt(for: normalizedName)
                            return (nil, getCategoryColors(for: storeName))
                        }

                        let colors = image.dominantColors(count: 3)
                        let finalColors = colors.isEmpty ? defaultColors : colors

                        print("✅ Successfully fetched and validated logo for: \(storeName)")

                        // Cache the successful result on the main thread
                        await MainActor.run {
                            LogoCache.shared.logoCache[normalizedName] = (image, finalColors)
                            // Remove from failed attempts if it was there
                            LogoCache.shared.failedAttempts.removeValue(forKey: normalizedName)
                        }

                        return (image, finalColors)
                    } catch {
                        print("Error fetching logo image: \(error.localizedDescription)")
                        retryCount += 1
                        if retryCount > maxRetries {
                            cacheFailedAttempt(for: normalizedName)
                            return (nil, defaultColors)
                        }
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    retryCount += 1
                    if retryCount > maxRetries {
                        cacheFailedAttempt(for: normalizedName)
                        return (nil, defaultColors)
                    }
                    continue
                }
            } catch {
                print("Network error fetching logo: \(error)")
                retryCount += 1
                if retryCount > maxRetries {
                    cacheFailedAttempt(for: normalizedName)
                    return (nil, defaultColors)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
            }
        }

        cacheFailedAttempt(for: normalizedName)
        return (nil, defaultColors)
    }

    // Helper method to cache a failed attempt
    private func cacheFailedAttempt(for storeKey: String) {
        Task { @MainActor in
            // Cache a nil image with category-specific colors
            let colors = self.getCategoryColors(for: storeKey)
            LogoCache.shared.logoCache[storeKey] = (nil, colors)
            // Record the failure timestamp
            LogoCache.shared.failedAttempts[storeKey] = Date()
        }
    }

    // Validate if a logo is likely correct for the store
    private func validateLogo(image: UIImage, for storeName: String) -> Bool {
        // Basic validation - check if image is not too small or generic
        let imageSize = image.size

        // Reject very small images (likely low quality)
        if imageSize.width < 32 || imageSize.height < 32 {
            print("❌ Logo rejected: too small (\(imageSize.width)x\(imageSize.height))")
            return false
        }

        // Reject very large images (likely not logos)
        if imageSize.width > 1000 || imageSize.height > 1000 {
            print("❌ Logo rejected: too large (\(imageSize.width)x\(imageSize.height))")
            return false
        }

        // Additional validation could be added here (e.g., checking dominant colors, aspect ratio)
        print("✅ Logo validated for: \(storeName)")
        return true
    }

    // Enhanced logo fetching with better search terms
    func fetchLogoForReceipt(_ receipt: Receipt) async -> (UIImage?, [Color]) {
        let cache = LogoCache.shared
        let cacheKey = cache.generateCacheKey(for: receipt)

        print("🔍 Fetching logo for receipt: '\(receipt.store_name)' with key: '\(cacheKey)'")

        // Check cache first
        if let cached = cache.logoCache[cacheKey] {
            print("📦 Using cached logo for: '\(cacheKey)'")
            return (cached.image, cached.colors)
        }

        // Use logo_search_term if available, otherwise fall back to store_name
        let searchTerm = receipt.logo_search_term?.trimmingCharacters(in: .whitespacesAndNewlines) ?? receipt.store_name
        return await fetchLogo(for: searchTerm, cacheKey: cacheKey)
    }

    // Enhanced logo fetching for store locations
    func fetchLogoForStoreLocation(_ storeLocation: StoreLocation) async -> (UIImage?, [Color]) {
        let cache = LogoCache.shared
        let cacheKey = cache.generateCacheKey(for: storeLocation)

        print("🔍 Fetching logo for store location: '\(storeLocation.name)' with key: '\(cacheKey)'")

        // Check cache first
        if let cached = cache.logoCache[cacheKey] {
            print("📦 Using cached logo for: '\(cacheKey)'")
            return (cached.image, cached.colors)
        }

        return await fetchLogo(for: storeLocation.logoSearchTerm, cacheKey: cacheKey)
    }

    // Internal method with cache key parameter
    private func fetchLogo(for searchTerm: String, cacheKey: String) async -> (UIImage?, [Color]) {
        // Handle empty search terms
        guard !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, defaultColors)
        }

        let cache = LogoCache.shared

        // Check for known store name corrections
        if let correctedName = checkForKnownStore(cacheKey) {
            print("✅ Found correction: '\(cacheKey)' -> '\(correctedName)'")
            // Add mapping for future reference on main thread
            await MainActor.run {
                cache.addNameMapping(from: cacheKey, to: correctedName)
            }

            // Check if we have the corrected name in cache
            if let cached = cache.logoCache[correctedName] {
                print("📦 Using cached logo for corrected name: '\(correctedName)'")
                return (cached.image, cached.colors)
            }
        }

        // Only attempt to fetch if we haven't recently failed
        if !cache.shouldAttemptFetch(for: cacheKey) {
            print("⏳ Skipping fetch for '\(cacheKey)' - recent failure")
            return (nil, getCategoryColors(for: searchTerm))
        }

        return await fetchLogoFromAPI(storeName: searchTerm, normalizedName: cacheKey)
    }

    // Generate a placeholder image for a store
    func generatePlaceholderImage(for storeName: String, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let cache = LogoCache.shared
        let _ = cache.normalizeStoreName(storeName)
        let colors = getCategoryColors(for: storeName)

        // Create a renderer with the specified size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Fill background with the primary color
            colors.first?.uiColor().setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw the first letter of the store name
            let letter = String(storeName.prefix(1)).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.5, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = letter.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            letter.draw(in: textRect, withAttributes: attributes)
        }
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
        print("🔄 [HistoryView] Starting fetchReceipts...")
        if appState.useLocalStorage {
            print("💾 [HistoryView] Using local storage mode")
            // Get receipts from local storage
            let localReceipts = LocalStorageService.shared.getReceipts()
            print("💾 [HistoryView] Retrieved \(localReceipts.count) receipts from local storage")

            // Pre-fetch logos for receipts using enhanced method
            for receipt in localReceipts {
                let cache = LogoCache.shared
                let cacheKey = cache.generateCacheKey(for: receipt)
                if !cache.logoCache.keys.contains(cacheKey) &&
                   cache.shouldAttemptFetch(for: cacheKey) {
                    Task {
                        _ = await LogoService.shared.fetchLogoForReceipt(receipt)
                    }
                }
            }

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

            // Pre-fetch logos for receipts using enhanced method
            for receipt in fetchedReceipts {
                let cache = LogoCache.shared
                let cacheKey = cache.generateCacheKey(for: receipt)
                if !cache.logoCache.keys.contains(cacheKey) &&
                   cache.shouldAttemptFetch(for: cacheKey) {
                    Task {
                        _ = await LogoService.shared.fetchLogoForReceipt(receipt)
                    }
                }
            }

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
                    // Clean up old cache entries periodically
                    LogoCache.shared.cleanupCache()
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
    @StateObject private var currencyManager = CurrencyManager.shared
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
        // Use the enhanced logo fetching method
        Task {
            let (image, colors) = await LogoService.shared.fetchLogoForReceipt(receipt)
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
    @StateObject private var currencyManager = CurrencyManager.shared

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
                        Text(currencyManager.formatAmount(originalPrice, currencyCode: currencyManager.preferredCurrency))
                            .font(.spaceGrotesk(size: 14))
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .green.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Text(currencyManager.formatAmount(item.price, currencyCode: currencyManager.preferredCurrency))
                        .font(.spaceGrotesk(size: 18, weight: .bold))
                        .foregroundColor(priceColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7) // Shrink text to fit if needed
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
