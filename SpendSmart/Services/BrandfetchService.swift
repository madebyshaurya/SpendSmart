//
//  BrandfetchService.swift
//  SpendSmart
//
//  Created by AI Assistant on 2025-01-25.
//

import Foundation
import UIKit
import SwiftUI

/// Service to fetch company logos and brand information from Brandfetch API
class BrandfetchService: ObservableObject {
    static let shared = BrandfetchService()

    private let baseURL = "https://api.brandfetch.io/v2"
    private let cache = NSCache<NSString, UIImage>()
    private let colorCache = NSCache<NSString, NSArray>()
    private let urlCache = NSCache<NSString, NSString>()

    private var apiKey: String {
        return brandfetchAPIKey
    }

    private init() {
        cache.countLimit = 100 // Limit cache to 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB cache limit
    }

    // MARK: - Public API

    /// Fetch logo URL for a company/brand by name or domain
    /// - Parameters:
    ///   - companyName: The name or domain of the company (e.g., "netflix" or "netflix.com")
    ///   - size: Size parameter (ignored, kept for compatibility)
    /// - Returns: URL string for the logo or nil if not found
    func getLogoURL(for companyName: String, size: Int = 128) -> String? {
        let cacheKey = companyName.lowercased() as NSString

        // Check cache first
        if let cachedURL = urlCache.object(forKey: cacheKey) {
            return cachedURL as String
        }

        // Note: Brandfetch requires an async API call to get the URL
        // For synchronous access, return nil and let the caller use fetchLogo instead
        return nil
    }

    /// Fetch logo URL for a company/brand by domain (async version)
    /// - Parameters:
    ///   - domain: The domain of the company (e.g., "netflix.com")
    /// - Returns: URL string for the logo or nil if not found
    private func getLogoURLAsync(for domain: String) async -> String? {
        let cleanDomain = cleanDomain(domain)
        guard !cleanDomain.isEmpty else { return nil }

        let cacheKey = cleanDomain as NSString

        // Check cache first
        if let cachedURL = urlCache.object(forKey: cacheKey) {
            return cachedURL as String
        }

        do {
            let brandData = try await fetchBrandData(domain: cleanDomain)

            // Extract logo URL from brand data
            if let logos = brandData["logos"] as? [[String: Any]],
               let firstLogo = logos.first,
               let formats = firstLogo["formats"] as? [[String: Any]] {

                // Prefer PNG format
                for format in formats {
                    if let formatType = format["format"] as? String,
                       formatType == "png",
                       let src = format["src"] as? String {
                        urlCache.setObject(src as NSString, forKey: cacheKey)
                        return src
                    }
                }

                // Fallback to any format
                if let src = formats.first?["src"] as? String {
                    urlCache.setObject(src as NSString, forKey: cacheKey)
                    return src
                }
            }
        } catch {
            print("❌ [BrandfetchService] Failed to fetch brand data for \(domain): \(error)")
        }

        return nil
    }

    /// Fetch logo image for a company/brand
    /// - Parameters:
    ///   - companyName: The name of the company
    ///   - size: The desired size of the logo
    /// - Returns: UIImage or nil if not found
    func fetchLogo(for companyName: String, size: Int = 128) async -> UIImage? {
        let cacheKey = "\(companyName.lowercased())_\(size)" as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        let domain = nameToDomain(companyName)
        guard let logoURL = await getLogoURLAsync(for: domain),
              let url = URL(string: logoURL) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let image = UIImage(data: data) {

                // Cache the image and URL
                let cost = data.count
                cache.setObject(image, forKey: cacheKey, cost: cost)
                urlCache.setObject(logoURL as NSString, forKey: companyName.lowercased() as NSString)

                return image
            }
        } catch {
            print("❌ [BrandfetchService] Failed to fetch logo for \(companyName): \(error)")
        }

        return nil
    }

    /// Fetch logo and colors for a receipt
    /// - Parameter receipt: The receipt to fetch logo for
    /// - Returns: Tuple of (UIImage, [Color]) - always returns a valid image (placeholder if needed)
    func fetchLogoForReceipt(_ receipt: Receipt) async -> (UIImage, [Color]) {
        let storeName = receipt.store_name
        let (image, colors) = await fetchLogoAndColors(for: storeName)

        // If we didn't get an image, generate a placeholder
        if let image = image {
            return (image, colors)
        } else {
            let placeholder = generatePlaceholderImage(for: storeName)
            return (placeholder, colors)
        }
    }

    /// Fetch logo and colors for a store location (used by MapMarkerView)
    /// - Parameter storeLocation: The store location
    /// - Returns: Tuple of (UIImage?, [Color])
    func fetchLogoForStoreLocation(_ storeLocation: StoreLocation) async -> (UIImage?, [Color]) {
        return await fetchLogoAndColors(for: storeLocation.name)
    }

    /// Fetch logo and colors for a store name
    /// - Parameter storeName: The name of the store
    /// - Returns: Tuple of (UIImage?, [Color])
    func fetchLogoAndColors(for storeName: String) async -> (UIImage?, [Color]) {
        let cacheKey = storeName.lowercased() as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey),
           let cachedColors = colorCache.object(forKey: cacheKey) as? [Color] {
            return (cachedImage, cachedColors)
        }

        let domain = nameToDomain(storeName)

        do {
            let brandData = try await fetchBrandData(domain: domain)

            // Extract logo URL
            var logoImage: UIImage?
            if let logos = brandData["logos"] as? [[String: Any]],
               let firstLogo = logos.first,
               let formats = firstLogo["formats"] as? [[String: Any]] {

                // Get logo URL
                var logoURLString: String?
                for format in formats {
                    if let formatType = format["format"] as? String,
                       formatType == "png",
                       let src = format["src"] as? String {
                        logoURLString = src
                        break
                    }
                }

                if logoURLString == nil, let src = formats.first?["src"] as? String {
                    logoURLString = src
                }

                // Fetch logo image
                if let logoURLString = logoURLString,
                   let url = URL(string: logoURLString) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    logoImage = UIImage(data: data)

                    // Cache the URL
                    urlCache.setObject(logoURLString as NSString, forKey: cacheKey)
                }
            }

            // Extract brand colors
            var colors: [Color] = []
            if let brandColors = brandData["colors"] as? [[String: Any]] {
                for colorData in brandColors.prefix(3) {
                    if let hex = colorData["hex"] as? String {
                        let color = Color(hex: hex)
                        colors.append(color)
                    }
                }
            }

            // Fallback to generated colors if no colors found
            if colors.isEmpty {
                colors = generateColors(for: storeName)
            }

            // Cache results
            if let logoImage = logoImage {
                cache.setObject(logoImage, forKey: cacheKey)
            }
            colorCache.setObject(colors as NSArray, forKey: cacheKey)

            return (logoImage, colors)

        } catch {
            print("❌ [BrandfetchService] Failed to fetch brand data for \(storeName): \(error)")
        }

        // Fallback: Generate placeholder colors
        let colors = generateColors(for: storeName)
        return (nil, colors)
    }

    // MARK: - Private Helpers

    /// Fetch brand data from Brandfetch API
    private func fetchBrandData(domain: String) async throws -> [String: Any] {
        let cleanDomain = cleanDomain(domain)
        guard let url = URL(string: "\(baseURL)/brands/\(cleanDomain)") else {
            throw BrandfetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        print("🔍 [BrandfetchService] Fetching brand data from: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrandfetchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ [BrandfetchService] API returned status code: \(httpResponse.statusCode)")
            throw BrandfetchError.apiError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrandfetchError.invalidJSON
        }

        print("✅ [BrandfetchService] Successfully fetched brand data for \(domain)")
        return json
    }

    /// Convert company name to domain format
    private func nameToDomain(_ name: String) -> String {
        let cleaned = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")

        // If it already looks like a domain, return as is
        if cleaned.contains(".") {
            return cleaned
        }

        // Otherwise append .com
        return "\(cleaned).com"
    }

    /// Clean domain string
    private func cleanDomain(_ domain: String) -> String {
        var cleaned = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove http/https prefix
        cleaned = cleaned.replacingOccurrences(of: "https://", with: "")
        cleaned = cleaned.replacingOccurrences(of: "http://", with: "")

        // Remove www prefix
        cleaned = cleaned.replacingOccurrences(of: "www.", with: "")

        // Remove trailing slash
        if cleaned.hasSuffix("/") {
            cleaned = String(cleaned.dropLast())
        }

        // If no domain extension, add .com
        if !cleaned.contains(".") {
            cleaned = "\(cleaned).com"
        }

        return cleaned
    }

    /// Generate placeholder colors based on store name
    private func generateColors(for storeName: String) -> [Color] {
        let hash = abs(storeName.lowercased().hashValue)
        let hue = Double(hash % 360) / 360.0

        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.8),
            Color(hue: hue, saturation: 0.5, brightness: 0.7),
            Color(hue: hue, saturation: 0.4, brightness: 0.6)
        ]
    }

    /// Generate placeholder image with store initials
    func generatePlaceholderImage(for storeName: String, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let colors = generateColors(for: storeName)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw gradient background
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(colors[0]).cgColor, UIColor(colors[1]).cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Draw store initials
            let initials = getInitials(from: storeName)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let fontSize = min(size.width, size.height) * 0.4
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let textSize = initials.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            initials.draw(in: textRect, withAttributes: attributes)
        }

        return image
    }

    /// Get initials from store name
    private func getInitials(from name: String) -> String {
        let words = name.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let firstWord = words.first {
            return String(firstWord.prefix(2)).uppercased()
        }

        return "?"
    }

    /// Clear all caches
    func clearCache() {
        cache.removeAllObjects()
        colorCache.removeAllObjects()
        urlCache.removeAllObjects()
    }
}

// MARK: - Error Types

enum BrandfetchError: Error {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case apiError(statusCode: Int)
}

// Note: Color.init(hex:) extension is already defined in Utils/Extensions.swift
