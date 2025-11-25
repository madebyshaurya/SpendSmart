//
//  CurrencyManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation
import SwiftUI

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()

    // UserDefaults keys
    private let preferredCurrencyKey = "preferred_currency"
    private let recentCurrenciesKey = "recent_currencies"

    // Published properties for SwiftUI binding
    @Published var preferredCurrency: String {
        didSet {
            UserDefaults.standard.set(preferredCurrency, forKey: preferredCurrencyKey)
            addToRecentCurrencies(preferredCurrency)
            // Sync change to Supabase so the user's onboarding record stays current
            Task { await syncPreferredCurrencyToSupabase(preferredCurrency) }
        }
    }

    // Exchange rate service
    private let exchangeRateService = ExchangeRateService.shared

    // Published properties for UI updates
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var conversionError: Error?
    @Published var recentCurrencies: [String] = []

    // Currency data structure
    struct CurrencyInfo {
        let code: String
        let symbol: String
        let name: String
        let symbolIsPrefix: Bool
        let decimalSeparator: String
        let thousandsSeparator: String
        let exampleFormat: String
    }

    // List of supported currencies with their information
    let supportedCurrencies: [CurrencyInfo] = [
        // Major currencies
        CurrencyInfo(code: "USD", symbol: "$", name: "US Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "$1,234.56"),
        CurrencyInfo(code: "EUR", symbol: "€", name: "Euro", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "€1.234,56"),
        CurrencyInfo(code: "GBP", symbol: "£", name: "British Pound", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "£1,234.56"),
        CurrencyInfo(code: "JPY", symbol: "¥", name: "Japanese Yen", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "¥1,235"),
        CurrencyInfo(code: "CAD", symbol: "CA$", name: "Canadian Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "CA$1,234.56"),
        CurrencyInfo(code: "AUD", symbol: "A$", name: "Australian Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "A$1,234.56"),
        CurrencyInfo(code: "CHF", symbol: "Fr.", name: "Swiss Franc", symbolIsPrefix: false, decimalSeparator: ".", thousandsSeparator: "'", exampleFormat: "1'234.56 Fr."),

        // Asian currencies
        CurrencyInfo(code: "CNY", symbol: "¥", name: "Chinese Yuan", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "¥1,234.56"),
        CurrencyInfo(code: "HKD", symbol: "HK$", name: "Hong Kong Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "HK$1,234.56"),
        CurrencyInfo(code: "SGD", symbol: "S$", name: "Singapore Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "S$1,234.56"),
        CurrencyInfo(code: "INR", symbol: "₹", name: "Indian Rupee", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "₹1,234.56"),
        CurrencyInfo(code: "KRW", symbol: "₩", name: "South Korean Won", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "₩1,235"),
        CurrencyInfo(code: "MYR", symbol: "RM", name: "Malaysian Ringgit", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "RM1,234.56"),
        CurrencyInfo(code: "THB", symbol: "฿", name: "Thai Baht", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "฿1,234.56"),
        CurrencyInfo(code: "IDR", symbol: "Rp", name: "Indonesian Rupiah", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "Rp1.234,56"),
        CurrencyInfo(code: "PHP", symbol: "₱", name: "Philippine Peso", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "₱1,234.56"),
        CurrencyInfo(code: "TWD", symbol: "NT$", name: "Taiwan Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "NT$1,234.56"),

        // European currencies
        CurrencyInfo(code: "SEK", symbol: "kr", name: "Swedish Krona", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 234,56 kr"),
        CurrencyInfo(code: "NOK", symbol: "kr", name: "Norwegian Krone", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 234,56 kr"),
        CurrencyInfo(code: "DKK", symbol: "kr", name: "Danish Krone", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "1.234,56 kr"),
        CurrencyInfo(code: "PLN", symbol: "zł", name: "Polish Złoty", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 234,56 zł"),
        CurrencyInfo(code: "CZK", symbol: "Kč", name: "Czech Koruna", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 234,56 Kč"),
        CurrencyInfo(code: "HUF", symbol: "Ft", name: "Hungarian Forint", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 235 Ft"),
        CurrencyInfo(code: "RON", symbol: "lei", name: "Romanian Leu", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "1.234,56 lei"),
        CurrencyInfo(code: "BGN", symbol: "лв", name: "Bulgarian Lev", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "1 234,56 лв"),
        CurrencyInfo(code: "HRK", symbol: "kn", name: "Croatian Kuna", symbolIsPrefix: false, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "1.234,56 kn"),
        CurrencyInfo(code: "RUB", symbol: "₽", name: "Russian Ruble", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: " ", exampleFormat: "₽1 234,56"),
        CurrencyInfo(code: "TRY", symbol: "₺", name: "Turkish Lira", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "₺1.234,56"),

        // Americas
        CurrencyInfo(code: "BRL", symbol: "R$", name: "Brazilian Real", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "R$1.234,56"),
        CurrencyInfo(code: "MXN", symbol: "Mex$", name: "Mexican Peso", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "Mex$1,234.56"),
        CurrencyInfo(code: "ARS", symbol: "$", name: "Argentine Peso", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "$1.234,56"),
        CurrencyInfo(code: "CLP", symbol: "$", name: "Chilean Peso", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "$1.235"),
        CurrencyInfo(code: "COP", symbol: "$", name: "Colombian Peso", symbolIsPrefix: true, decimalSeparator: ",", thousandsSeparator: ".", exampleFormat: "$1.234,56"),
        CurrencyInfo(code: "PEN", symbol: "S/", name: "Peruvian Sol", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "S/1,234.56"),

        // Oceania
        CurrencyInfo(code: "NZD", symbol: "NZ$", name: "New Zealand Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "NZ$1,234.56"),
        CurrencyInfo(code: "FJD", symbol: "FJ$", name: "Fijian Dollar", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "FJ$1,234.56"),

        // Middle East & Africa
        CurrencyInfo(code: "AED", symbol: "د.إ", name: "UAE Dirham", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "د.إ1,234.56"),
        CurrencyInfo(code: "SAR", symbol: "﷼", name: "Saudi Riyal", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "﷼1,234.56"),
        CurrencyInfo(code: "ILS", symbol: "₪", name: "Israeli Shekel", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "₪1,234.56"),
        CurrencyInfo(code: "EGP", symbol: "E£", name: "Egyptian Pound", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "E£1,234.56"),
        CurrencyInfo(code: "ZAR", symbol: "R", name: "South African Rand", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "R1,234.56"),
        CurrencyInfo(code: "NGN", symbol: "₦", name: "Nigerian Naira", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "₦1,234.56"),
        CurrencyInfo(code: "KES", symbol: "KSh", name: "Kenyan Shilling", symbolIsPrefix: true, decimalSeparator: ".", thousandsSeparator: ",", exampleFormat: "KSh1,234.56")
    ]

    // Initialize with default currency or saved preference
    init() {
        // Load preferred currency from UserDefaults or use USD as default
        self.preferredCurrency = UserDefaults.standard.string(forKey: preferredCurrencyKey) ?? "USD"

        // Load recent currencies from UserDefaults
        if let recentCurrenciesData = UserDefaults.standard.array(forKey: recentCurrenciesKey) as? [String] {
            self.recentCurrencies = recentCurrenciesData
        } else {
            // Initialize with preferred currency
            self.recentCurrencies = [self.preferredCurrency]
        }

        // Sync with exchange rate service
        self.lastUpdated = exchangeRateService.lastUpdated
    }

    // Add a currency to recent currencies list
    private func addToRecentCurrencies(_ currencyCode: String) {
        // Remove if already exists
        recentCurrencies.removeAll { $0 == currencyCode }

        // Add to the beginning
        recentCurrencies.insert(currencyCode, at: 0)

        // Limit to 5 recent currencies
        if recentCurrencies.count > 5 {
            recentCurrencies = Array(recentCurrencies.prefix(5))
        }

        // Save to UserDefaults
        UserDefaults.standard.set(recentCurrencies, forKey: recentCurrenciesKey)
    }

    // Get currency info for a specific currency code
    func getCurrencyInfo(for currencyCode: String) -> CurrencyInfo? {
        return supportedCurrencies.first { $0.code == currencyCode }
    }

    // Get currency info for the preferred currency
    func getPreferredCurrencyInfo() -> CurrencyInfo? {
        return getCurrencyInfo(for: preferredCurrency)
    }

    // Get currency symbol for a specific currency code
    func getCurrencySymbol(for currencyCode: String) -> String {
        return getCurrencyInfo(for: currencyCode)?.symbol ?? "$"
    }

    // Format amount according to currency rules
    func formatAmount(_ amount: Double, currencyCode: String, compact: Bool = false) -> String {
        guard let currencyInfo = getCurrencyInfo(for: currencyCode) else {
            // Fallback to basic formatting if currency not found
            return String(format: "$%.2f", amount)
        }

        // Create a number formatter for proper locale-specific formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        // Set decimal and thousands separators based on currency info
        formatter.decimalSeparator = currencyInfo.decimalSeparator
        formatter.groupingSeparator = currencyInfo.thousandsSeparator
        formatter.usesGroupingSeparator = true

        // For JPY and similar currencies, don't show decimal places
        if currencyCode == "JPY" || currencyCode == "HUF" || currencyCode == "KRW" || currencyCode == "CLP" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }

        // For compact display (used in tight spaces), simplify large numbers
        if compact && amount >= 1000 {
            if amount >= 1000000 {
                // For millions, show as 1.2M
                let millions = amount / 1000000
                formatter.maximumFractionDigits = 1
                guard let formattedMillions = formatter.string(from: NSNumber(value: millions)) else {
                    return String(format: "%.1fM", millions)
                }
                return currencyInfo.symbolIsPrefix ?
                    "\(currencyInfo.symbol)\(formattedMillions)M" :
                    "\(formattedMillions)M\u{00A0}\(currencyInfo.symbol)"
            } else {
                // For thousands, show as 1.2K
                let thousands = amount / 1000
                formatter.maximumFractionDigits = 1
                guard let formattedThousands = formatter.string(from: NSNumber(value: thousands)) else {
                    return String(format: "%.1fK", thousands)
                }
                return currencyInfo.symbolIsPrefix ?
                    "\(currencyInfo.symbol)\(formattedThousands)K" :
                    "\(formattedThousands)K\u{00A0}\(currencyInfo.symbol)"
            }
        }

        // Format the number
        guard let formattedAmount = formatter.string(from: NSNumber(value: amount)) else {
            // Fallback if formatting fails
            return String(format: "%.2f", amount)
        }

        // Apply symbol based on prefix/suffix preference with non-breaking space
        if currencyInfo.symbolIsPrefix {
            return "\(currencyInfo.symbol)\(formattedAmount)"
        } else {
            return "\(formattedAmount)\u{00A0}\(currencyInfo.symbol)"  // Use non-breaking space
        }
    }

    // Format amount in the user's preferred currency
    func formatAmountInPreferredCurrency(_ amount: Double, originalCurrency: String) -> String {
        // Use the synchronous version for UI formatting
        let convertedAmount = convertAmountSync(amount, from: originalCurrency, to: preferredCurrency)
        return formatAmount(convertedAmount, currencyCode: preferredCurrency)
    }

    // MARK: - Cloud sync
    private func syncPreferredCurrencyToSupabase(_ currencyCode: String) async {
        // Ensure user is authenticated
        guard let user = await SupabaseManager.shared.getCurrentUser() else {
            print("ℹ️ [CurrencyManager] Skipping Supabase sync (no user)")
            return
        }

        struct UpdateCurrency: Encodable { let currency_preference: String }
        let supabase = SupabaseManager.shared.supabaseClient

        do {
            // Try update existing row for this user
            try await supabase
                .from("user_onboarding")
                .update(UpdateCurrency(currency_preference: currencyCode))
                .eq("user_id", value: user.id)
                .execute()
            print("✅ [CurrencyManager] Updated currency_preference → \(currencyCode) for user \(user.id)")
        } catch {
            // Fallback: upsert minimal row if none exists yet
            print("⚠️ [CurrencyManager] Update failed, attempting upsert: \(error.localizedDescription)")
            struct UpsertRow: Encodable { let user_id: String; let currency_preference: String }
            do {
                try await supabase
                    .from("user_onboarding")
                    .upsert(UpsertRow(user_id: user.id, currency_preference: currencyCode), onConflict: "user_id")
                    .execute()
                print("✅ [CurrencyManager] Upserted currency_preference for user \(user.id)")
            } catch {
                print("❌ [CurrencyManager] Failed to sync currency to Supabase: \(error.localizedDescription)")
            }
        }
    }

    // Asynchronous conversion between currencies using real-time rates
    func convertAmount(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) async -> Double {
        // If currencies are the same, no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }

        // Update UI state on the main thread
        await MainActor.run {
            isLoading = true
        }

        do {
            // Use the exchange rate service for conversion
            let convertedAmount = try await exchangeRateService.convertAmount(amount, from: sourceCurrency, to: targetCurrency)

            // Update UI state on the main thread
            await MainActor.run {
                lastUpdated = exchangeRateService.lastUpdated
                isLoading = false
                conversionError = nil
            }

            return convertedAmount
        } catch {
            // Handle error and return original amount as fallback
            await MainActor.run {
                isLoading = false
                conversionError = error
            }

            // Fallback to sync conversion if API fails
            return convertAmountSync(amount, from: sourceCurrency, to: targetCurrency)
        }
    }

    // Synchronous conversion using cached rates (fallback method)
    func convertAmountSync(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double {
        // If currencies are the same, no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }

        // Get cached rates from the exchange rate service
        if let rates = exchangeRateService.exchangeRatesCache[sourceCurrency],
           let rate = rates[targetCurrency] {
            return amount * rate
        }

        // If no cached rates, use approximate conversion via USD
        // This is a fallback mechanism when the API is unavailable
        let approximateUSDRates: [String: Double] = [
            // Major currencies
            "USD": 1.0,
            "EUR": 0.92,
            "GBP": 0.79,
            "JPY": 154.82,
            "CAD": 1.36,
            "AUD": 1.51,
            "CHF": 0.90,

            // Asian currencies
            "CNY": 7.23,
            "HKD": 7.81,
            "SGD": 1.34,
            "INR": 83.45,
            "KRW": 1350.0,
            "MYR": 4.65,
            "THB": 35.5,
            "IDR": 15600.0,
            "PHP": 56.8,
            "TWD": 31.5,

            // European currencies
            "SEK": 10.42,
            "NOK": 10.71,
            "DKK": 6.86,
            "PLN": 3.95,
            "CZK": 22.8,
            "HUF": 355.0,
            "RON": 4.57,
            "BGN": 1.80,
            "HRK": 7.0,
            "RUB": 92.50,
            "TRY": 31.8,

            // Americas
            "BRL": 5.05,
            "MXN": 16.73,
            "ARS": 870.0,
            "CLP": 950.0,
            "COP": 3900.0,
            "PEN": 3.7,

            // Oceania
            "NZD": 1.63,
            "FJD": 2.25,

            // Middle East & Africa
            "AED": 3.67,
            "SAR": 3.75,
            "ILS": 3.65,
            "EGP": 30.9,
            "ZAR": 18.5,
            "NGN": 1450.0,
            "KES": 130.0
        ]

        // Convert via USD as the intermediate currency
        guard let sourceRate = approximateUSDRates[sourceCurrency],
              let targetRate = approximateUSDRates[targetCurrency] else {
            // If we don't have the exchange rate, return the original amount
            return amount
        }

        let amountInUSD = amount / sourceRate
        return amountInUSD * targetRate
    }

    // Format amount with both original and converted currencies
    func formatAmountWithConversion(_ amount: Double, originalCurrency: String) -> String {
        // If original currency is the same as preferred, just format normally
        if originalCurrency == preferredCurrency {
            return formatAmount(amount, currencyCode: originalCurrency)
        }

        // Otherwise, show both
        let originalFormatted = formatAmount(amount, currencyCode: originalCurrency)
        let convertedAmount = convertAmountSync(amount, from: originalCurrency, to: preferredCurrency)
        let convertedFormatted = formatAmount(convertedAmount, currencyCode: preferredCurrency)

        return "\(originalFormatted) (\(convertedFormatted))"
    }

    // Get a list of currency codes
    func getCurrencyCodes() -> [String] {
        return supportedCurrencies.map { $0.code }
    }

    // Search currencies by code or name with improved matching
    func searchCurrencies(query: String) -> [CurrencyInfo] {
        if query.isEmpty {
            return supportedCurrencies
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedQuery = trimmedQuery.lowercased()

        // First, check for exact matches on currency code (highest priority)
        let exactCodeMatches = supportedCurrencies.filter { currency in
            currency.code.lowercased() == lowercasedQuery
        }

        if !exactCodeMatches.isEmpty {
            return exactCodeMatches
        }

        // Next, check for currencies where the code starts with the query
        let codeStartsWithMatches = supportedCurrencies.filter { currency in
            currency.code.lowercased().starts(with: lowercasedQuery)
        }

        // Then check for currencies where the name starts with the query
        let nameStartsWithMatches = supportedCurrencies.filter { currency in
            currency.name.lowercased().starts(with: lowercasedQuery)
        }

        // Finally, check for currencies where the code or name contains the query anywhere
        let containsMatches = supportedCurrencies.filter { currency in
            (currency.code.lowercased().contains(lowercasedQuery) && !currency.code.lowercased().starts(with: lowercasedQuery)) ||
            (currency.name.lowercased().contains(lowercasedQuery) && !currency.name.lowercased().starts(with: lowercasedQuery))
        }

        // Combine results in order of priority
        return codeStartsWithMatches + nameStartsWithMatches + containsMatches
    }

    // Force refresh exchange rates
    func refreshExchangeRates() async {
        // Update UI state on the main thread
        await MainActor.run {
            isLoading = true
        }

        do {
            // Refresh rates for the preferred currency
            _ = try await exchangeRateService.refreshRates(for: preferredCurrency)

            // Update UI state on the main thread
            await MainActor.run {
                lastUpdated = exchangeRateService.lastUpdated
                isLoading = false
                conversionError = nil
            }
        } catch {
            // Update UI state on the main thread
            await MainActor.run {
                isLoading = false
                conversionError = error
            }
        }
    }

    // Get the last updated timestamp as a formatted string
    func getLastUpdatedString() -> String {
        return exchangeRateService.getLastUpdatedString()
    }
}
