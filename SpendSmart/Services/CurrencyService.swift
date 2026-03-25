import Foundation
import SwiftUI

/// CurrencyService - Handles currency conversion with caching
/// Uses free ExchangeRate-API (https://open.er-api.com)
/// Updates once per day, caches locally for offline use
@MainActor
class CurrencyService: ObservableObject {
    static let shared = CurrencyService()
    
    // MARK: - Published Properties
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?
    
    // MARK: - User Preference
    @AppStorage("currencyCode") var preferredCurrency: String = "USD"
    
    // MARK: - Cached Rates
    private var cachedRates: [String: [String: Double]] = [:] // [baseCurrency: [targetCurrency: rate]]
    private var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Constants
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    private let baseURL = "https://open.er-api.com/v6/latest"
    
    // MARK: - Currency Data
    static let supportedCurrencies: [CurrencyInfo] = [
        CurrencyInfo(code: "USD", symbol: "$", name: "US Dollar", flag: "🇺🇸"),
        CurrencyInfo(code: "EUR", symbol: "€", name: "Euro", flag: "🇪🇺"),
        CurrencyInfo(code: "GBP", symbol: "£", name: "British Pound", flag: "🇬🇧"),
        CurrencyInfo(code: "CAD", symbol: "C$", name: "Canadian Dollar", flag: "🇨🇦"),
        CurrencyInfo(code: "AUD", symbol: "A$", name: "Australian Dollar", flag: "🇦🇺"),
        CurrencyInfo(code: "JPY", symbol: "¥", name: "Japanese Yen", flag: "🇯🇵"),
        CurrencyInfo(code: "INR", symbol: "₹", name: "Indian Rupee", flag: "🇮🇳"),
        CurrencyInfo(code: "CHF", symbol: "Fr", name: "Swiss Franc", flag: "🇨🇭"),
        CurrencyInfo(code: "CNY", symbol: "¥", name: "Chinese Yuan", flag: "🇨🇳"),
        CurrencyInfo(code: "HKD", symbol: "HK$", name: "Hong Kong Dollar", flag: "🇭🇰"),
        CurrencyInfo(code: "SGD", symbol: "S$", name: "Singapore Dollar", flag: "🇸🇬"),
        CurrencyInfo(code: "SEK", symbol: "kr", name: "Swedish Krona", flag: "🇸🇪"),
        CurrencyInfo(code: "KRW", symbol: "₩", name: "South Korean Won", flag: "🇰🇷"),
        CurrencyInfo(code: "MXN", symbol: "$", name: "Mexican Peso", flag: "🇲🇽"),
        CurrencyInfo(code: "NZD", symbol: "NZ$", name: "New Zealand Dollar", flag: "🇳🇿"),
        CurrencyInfo(code: "NOK", symbol: "kr", name: "Norwegian Krone", flag: "🇳🇴"),
        CurrencyInfo(code: "DKK", symbol: "kr", name: "Danish Krone", flag: "🇩🇰"),
        CurrencyInfo(code: "ZAR", symbol: "R", name: "South African Rand", flag: "🇿🇦"),
        CurrencyInfo(code: "RUB", symbol: "₽", name: "Russian Ruble", flag: "🇷🇺"),
        CurrencyInfo(code: "BRL", symbol: "R$", name: "Brazilian Real", flag: "🇧🇷"),
        CurrencyInfo(code: "THB", symbol: "฿", name: "Thai Baht", flag: "🇹🇭"),
        CurrencyInfo(code: "MYR", symbol: "RM", name: "Malaysian Ringgit", flag: "🇲🇾"),
        CurrencyInfo(code: "IDR", symbol: "Rp", name: "Indonesian Rupiah", flag: "🇮🇩"),
        CurrencyInfo(code: "PHP", symbol: "₱", name: "Philippine Peso", flag: "🇵🇭"),
        CurrencyInfo(code: "PLN", symbol: "zł", name: "Polish Zloty", flag: "🇵🇱"),
        CurrencyInfo(code: "TRY", symbol: "₺", name: "Turkish Lira", flag: "🇹🇷"),
        CurrencyInfo(code: "AED", symbol: "د.إ", name: "UAE Dirham", flag: "🇦🇪"),
        CurrencyInfo(code: "SAR", symbol: "﷼", name: "Saudi Riyal", flag: "🇸🇦"),
        CurrencyInfo(code: "ILS", symbol: "₪", name: "Israeli Shekel", flag: "🇮🇱"),
        CurrencyInfo(code: "TWD", symbol: "NT$", name: "Taiwan Dollar", flag: "🇹🇼"),
        CurrencyInfo(code: "CZK", symbol: "Kč", name: "Czech Koruna", flag: "🇨🇿"),
        CurrencyInfo(code: "HUF", symbol: "Ft", name: "Hungarian Forint", flag: "🇭🇺"),
        CurrencyInfo(code: "CLP", symbol: "$", name: "Chilean Peso", flag: "🇨🇱"),
        CurrencyInfo(code: "COP", symbol: "$", name: "Colombian Peso", flag: "🇨🇴"),
        CurrencyInfo(code: "PEN", symbol: "S/", name: "Peruvian Sol", flag: "🇵🇪"),
        CurrencyInfo(code: "ARS", symbol: "$", name: "Argentine Peso", flag: "🇦🇷"),
        CurrencyInfo(code: "VND", symbol: "₫", name: "Vietnamese Dong", flag: "🇻🇳"),
        CurrencyInfo(code: "EGP", symbol: "£", name: "Egyptian Pound", flag: "🇪🇬"),
        CurrencyInfo(code: "PKR", symbol: "₨", name: "Pakistani Rupee", flag: "🇵🇰"),
        CurrencyInfo(code: "BDT", symbol: "৳", name: "Bangladeshi Taka", flag: "🇧🇩"),
        CurrencyInfo(code: "NGN", symbol: "₦", name: "Nigerian Naira", flag: "🇳🇬"),
        CurrencyInfo(code: "KES", symbol: "KSh", name: "Kenyan Shilling", flag: "🇰🇪"),
        CurrencyInfo(code: "GHS", symbol: "₵", name: "Ghanaian Cedi", flag: "🇬🇭"),
        CurrencyInfo(code: "MAD", symbol: "د.م.", name: "Moroccan Dirham", flag: "🇲🇦"),
        CurrencyInfo(code: "QAR", symbol: "﷼", name: "Qatari Riyal", flag: "🇶🇦"),
        CurrencyInfo(code: "KWD", symbol: "د.ك", name: "Kuwaiti Dinar", flag: "🇰🇼"),
        CurrencyInfo(code: "BHD", symbol: ".د.ب", name: "Bahraini Dinar", flag: "🇧🇭"),
        CurrencyInfo(code: "OMR", symbol: "﷼", name: "Omani Rial", flag: "🇴🇲"),
    ]
    
    private init() {
        loadCachedRates()
    }
    
    // MARK: - Public Methods
    
    /// Convert amount from one currency to another
    func convert(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) async -> Double {
        // Same currency - no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }
        
        // Try to get rate
        if let rate = await getRate(from: sourceCurrency, to: targetCurrency) {
            return amount * rate
        }
        
        // Fallback - return original amount
        return amount
    }
    
    /// Convert to user's preferred currency
    func convertToPreferred(_ amount: Double, from sourceCurrency: String) async -> Double {
        return await convert(amount, from: sourceCurrency, to: preferredCurrency)
    }
    
    /// Get exchange rate between two currencies
    func getRate(from sourceCurrency: String, to targetCurrency: String) async -> Double? {
        // Same currency
        if sourceCurrency == targetCurrency {
            return 1.0
        }
        
        // Check cache first
        if let cachedRate = getCachedRate(from: sourceCurrency, to: targetCurrency) {
            return cachedRate
        }
        
        // Fetch new rates
        await fetchRates(for: sourceCurrency)
        
        // Try cache again
        return getCachedRate(from: sourceCurrency, to: targetCurrency)
    }
    
    /// Format amount with currency symbol
    func formatAmount(_ amount: Double, currency: String, showSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        
        if !showSymbol {
            formatter.currencySymbol = ""
        }
        
        // Handle currencies with no decimal places (JPY, KRW, etc.)
        let noDecimalCurrencies = ["JPY", "KRW", "VND", "IDR", "CLP", "HUF"]
        if noDecimalCurrencies.contains(currency) {
            formatter.maximumFractionDigits = 0
        }
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(String(format: "%.2f", amount))"
    }
    
    /// Format amount in user's preferred currency
    func formatInPreferred(_ amount: Double, from sourceCurrency: String) async -> String {
        let converted = await convertToPreferred(amount, from: sourceCurrency)
        return formatAmount(converted, currency: preferredCurrency)
    }
    
    /// Get currency symbol
    func getSymbol(for code: String) -> String {
        if let info = Self.supportedCurrencies.first(where: { $0.code == code }) {
            return info.symbol
        }
        
        // Fallback to NumberFormatter
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }
    
    /// Get currency info
    func getCurrencyInfo(for code: String) -> CurrencyInfo? {
        return Self.supportedCurrencies.first { $0.code == code }
    }
    
    /// Get rate description string
    func getRateDescription(from: String, to: String) async -> String? {
        guard let rate = await getRate(from: from, to: to) else { return nil }
        return "1 \(from) = \(String(format: "%.4f", rate)) \(to)"
    }
    
    /// Refresh rates for a currency
    func refreshRates(for baseCurrency: String) async {
        await fetchRates(for: baseCurrency, forceRefresh: true)
    }
    
    // MARK: - Private Methods
    
    private func getCachedRate(from source: String, to target: String) -> Double? {
        // Direct rate
        if let rates = cachedRates[source], let rate = rates[target] {
            // Check if cache is still valid
            if let timestamp = cacheTimestamps[source],
               Date().timeIntervalSince(timestamp) < cacheValidityDuration {
                return rate
            }
        }
        
        // Try reverse rate
        if let rates = cachedRates[target], let rate = rates[source], rate > 0 {
            if let timestamp = cacheTimestamps[target],
               Date().timeIntervalSince(timestamp) < cacheValidityDuration {
                return 1.0 / rate
            }
        }
        
        // Try via USD (common intermediary)
        if source != "USD" && target != "USD" {
            if let sourceToUSD = cachedRates["USD"]?[source],
               let targetToUSD = cachedRates["USD"]?[target],
               sourceToUSD > 0 {
                // USD/source and USD/target -> source/target = (USD/target) / (USD/source) = target/source
                // Actually: source -> USD -> target
                // If we have USD as base: rates are USD/X
                // source -> USD = 1 / (USD/source)
                // USD -> target = USD/target
                // So source -> target = (1/sourceToUSD) * targetToUSD... wait that's wrong
                // If USD base, rates[X] = how many X per 1 USD
                // So to go from source to target:
                // source -> USD: 1/rates[source] USD per source
                // USD -> target: rates[target] target per USD
                // Combined: (1/sourceToUSD) * targetToUSD = targetToUSD / sourceToUSD
                return targetToUSD / sourceToUSD
            }
        }
        
        return nil
    }
    
    private func fetchRates(for baseCurrency: String, forceRefresh: Bool = false) async {
        // Check if we need to refresh
        if !forceRefresh,
           let timestamp = cacheTimestamps[baseCurrency],
           Date().timeIntervalSince(timestamp) < cacheValidityDuration,
           cachedRates[baseCurrency] != nil {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/\(baseCurrency)") else {
            lastError = "Invalid URL"
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 429 {
                lastError = "Rate limited - using cached data"
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                lastError = "HTTP \(httpResponse.statusCode)"
                return
            }
            
            let apiResponse = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            if apiResponse.result == "success" {
                cachedRates[baseCurrency] = apiResponse.rates
                cacheTimestamps[baseCurrency] = Date()
                lastUpdated = Date()
                lastError = nil
                saveCachedRates()
            } else {
                lastError = "API returned error"
            }
        } catch {
            lastError = error.localizedDescription
            print("CurrencyService fetch error: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func saveCachedRates() {
        let encoder = JSONEncoder()
        if let ratesData = try? encoder.encode(cachedRates),
           let timestampsData = try? encoder.encode(cacheTimestamps) {
            UserDefaults.standard.set(ratesData, forKey: "cached_exchange_rates")
            UserDefaults.standard.set(timestampsData, forKey: "exchange_rate_timestamps")
        }
    }
    
    private func loadCachedRates() {
        let decoder = JSONDecoder()
        if let ratesData = UserDefaults.standard.data(forKey: "cached_exchange_rates"),
           let timestampsData = UserDefaults.standard.data(forKey: "exchange_rate_timestamps") {
            cachedRates = (try? decoder.decode([String: [String: Double]].self, from: ratesData)) ?? [:]
            cacheTimestamps = (try? decoder.decode([String: Date].self, from: timestampsData)) ?? [:]
            
            // Set last updated from most recent timestamp
            lastUpdated = cacheTimestamps.values.max()
        }
    }
}

// MARK: - Models

struct CurrencyInfo: Identifiable, Hashable {
    let code: String
    let symbol: String
    let name: String
    let flag: String
    
    var id: String { code }
    
    var displayName: String {
        "\(flag) \(code) - \(name)"
    }
}

struct ExchangeRateResponse: Codable {
    let result: String
    let provider: String?
    let documentation: String?
    let termsOfUse: String?
    let timeLastUpdateUnix: Int?
    let timeLastUpdateUtc: String?
    let timeNextUpdateUnix: Int?
    let timeNextUpdateUtc: String?
    let baseCode: String?
    let rates: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case result
        case provider
        case documentation
        case termsOfUse = "terms_of_use"
        case timeLastUpdateUnix = "time_last_update_unix"
        case timeLastUpdateUtc = "time_last_update_utc"
        case timeNextUpdateUnix = "time_next_update_unix"
        case timeNextUpdateUtc = "time_next_update_utc"
        case baseCode = "base_code"
        case rates
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Format a price for display, converting to user's preferred currency if needed
    func currencyText(_ amount: Double, currency: String) -> some View {
        CurrencyText(amount: amount, currency: currency)
    }
}

struct CurrencyText: View {
    let amount: Double
    let currency: String
    @StateObject private var currencyService = CurrencyService.shared
    @State private var displayText: String = ""
    
    var body: some View {
        Text(displayText.isEmpty ? currencyService.formatAmount(amount, currency: currency) : displayText)
            .task {
                if currency != currencyService.preferredCurrency {
                    displayText = await currencyService.formatInPreferred(amount, from: currency)
                } else {
                    displayText = currencyService.formatAmount(amount, currency: currency)
                }
            }
    }
}

// MARK: - Currency Toggle Component

struct CurrencyToggleView: View {
    let amount: Double
    let originalCurrency: String
    @State private var showOriginal = true
    @StateObject private var currencyService = CurrencyService.shared
    @State private var convertedAmount: Double?
    @State private var rateDescription: String?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                if showOriginal {
                    Text(currencyService.formatAmount(amount, currency: originalCurrency))
                        .font(.ibmPlexMono(size: 18))
                        .bold()
                } else if let converted = convertedAmount {
                    Text(currencyService.formatAmount(converted, currency: currencyService.preferredCurrency))
                        .font(.ibmPlexMono(size: 18))
                        .bold()
                }
                
                if originalCurrency != currencyService.preferredCurrency {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            showOriginal.toggle()
                        }
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brandVibrantBlue)
                            .rotationEffect(.degrees(showOriginal ? 0 : 180))
                    }
                }
            }
            
            if !showOriginal, let rate = rateDescription {
                Text(rate)
                    .font(.manrope(size: 11))
                    .foregroundStyle(Color.brandTextTertiary)
            }
        }
        .task {
            if originalCurrency != currencyService.preferredCurrency {
                convertedAmount = await currencyService.convertToPreferred(amount, from: originalCurrency)
                rateDescription = await currencyService.getRateDescription(from: originalCurrency, to: currencyService.preferredCurrency)
            }
        }
    }
}
