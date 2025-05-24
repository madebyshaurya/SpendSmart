//
//  ExchangeRateService.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-15.
//

import Foundation
import Combine

class ExchangeRateService: ObservableObject {
    static let shared = ExchangeRateService()

    // Published properties
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // Cache for exchange rates (internal for CurrencyManager access)
    internal var exchangeRatesCache: [String: [String: Double]] = [:]

    // UserDefaults keys
    private let exchangeRatesCacheKey = "exchange_rates_cache"
    private let lastUpdatedKey = "exchange_rates_last_updated"

    // Cache expiration time (24 hours in seconds)
    private let cacheExpirationTime: TimeInterval = 24 * 60 * 60

    // Base URL for Frankfurter API
    private let baseURL = "https://api.frankfurter.app"

    // Initialize with cached data if available
    init() {
        loadCachedRates()
    }

    // Load cached exchange rates from UserDefaults
    private func loadCachedRates() {
        if let cachedData = UserDefaults.standard.data(forKey: exchangeRatesCacheKey),
           let lastUpdatedTimeInterval = UserDefaults.standard.object(forKey: lastUpdatedKey) as? TimeInterval {

            let lastUpdatedDate = Date(timeIntervalSince1970: lastUpdatedTimeInterval)
            self.lastUpdated = lastUpdatedDate

            // Check if cache is still valid
            if Date().timeIntervalSince(lastUpdatedDate) < cacheExpirationTime {
                do {
                    if let cachedRates = try JSONSerialization.jsonObject(with: cachedData) as? [String: [String: Double]] {
                        self.exchangeRatesCache = cachedRates
                        print("✅ Loaded exchange rates from cache")
                    }
                } catch {
                    print("❌ Error deserializing cached exchange rates: \(error.localizedDescription)")
                }
            } else {
                print("🔄 Exchange rates cache expired, will fetch fresh data")
            }
        }
    }

    // Save exchange rates to UserDefaults
    private func saveCacheToUserDefaults() {
        do {
            let data = try JSONSerialization.data(withJSONObject: exchangeRatesCache)
            UserDefaults.standard.set(data, forKey: exchangeRatesCacheKey)

            if let lastUpdated = lastUpdated {
                UserDefaults.standard.set(lastUpdated.timeIntervalSince1970, forKey: lastUpdatedKey)
            }

            print("✅ Saved exchange rates to cache")
        } catch {
            print("❌ Error serializing exchange rates for cache: \(error.localizedDescription)")
        }
    }

    // Fetch latest exchange rates for a base currency
    func fetchExchangeRates(for baseCurrency: String) async throws -> [String: Double] {
        // Check if we have cached rates for this base currency that are still valid
        if let cachedRates = exchangeRatesCache[baseCurrency],
           let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < cacheExpirationTime {
            return cachedRates
        }

        // If not in cache or expired, fetch from API
        await MainActor.run {
            isLoading = true
            error = nil
        }

        // Construct URL
        let urlString = "\(baseURL)/latest?from=\(baseCurrency)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        do {
            // Fetch data with retry mechanism
            let (data, response) = try await fetchWithRetry(url: url)

            // Parse response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }

            // Decode JSON
            let decoder = JSONDecoder()
            let ratesResponse = try decoder.decode(ExchangeRateResponse.self, from: data)

            // Update cache
            exchangeRatesCache[baseCurrency] = ratesResponse.rates
            lastUpdated = Date()

            // Save to UserDefaults
            saveCacheToUserDefaults()

            await MainActor.run {
                isLoading = false
            }

            return ratesResponse.rates
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error
            }
            throw error
        }
    }

    // Helper function to fetch with retry
    private func fetchWithRetry(url: URL, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var retryCount = 0
        var lastError: Error?

        while retryCount < maxRetries {
            do {
                return try await URLSession.shared.data(from: url)
            } catch {
                lastError = error
                retryCount += 1

                if retryCount < maxRetries {
                    // Exponential backoff: wait longer between each retry
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    // Convert amount between currencies
    func convertAmount(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) async throws -> Double {
        // If currencies are the same, no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }

        // Get exchange rates for source currency
        let rates = try await fetchExchangeRates(for: sourceCurrency)

        // Get rate for target currency
        guard let rate = rates[targetCurrency] else {
            throw CurrencyConversionError.rateNotFound
        }

        // Convert amount
        return amount * rate
    }

    // Force refresh exchange rates
    func refreshRates(for baseCurrency: String) async throws -> [String: Double] {
        // Clear cache for this currency
        exchangeRatesCache.removeValue(forKey: baseCurrency)

        // Fetch fresh rates
        return try await fetchExchangeRates(for: baseCurrency)
    }

    // Get the last updated timestamp as a formatted string
    func getLastUpdatedString() -> String {
        guard let lastUpdated = lastUpdated else {
            return "Never updated"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}

// Response model for Frankfurter API
struct ExchangeRateResponse: Codable {
    let amount: Double
    let base: String
    let date: String
    let rates: [String: Double]
}

// Custom error for currency conversion
enum CurrencyConversionError: Error {
    case rateNotFound
    case invalidCurrency
    case conversionFailed
}
