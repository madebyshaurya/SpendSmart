import Foundation
import SwiftUI
import UIKit

class BrandfetchService: ObservableObject {
    static let shared = BrandfetchService()
    private let baseURL = "https://api.brandfetch.io/v2"
    private let cache = NSCache<NSString, UIImage>()
    private let colorCache = NSCache<NSString, NSArray>()
    private let urlCache = NSCache<NSString, NSString>()
    private var apiKey: String { brandfetchAPIKey }

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func getLogoURL(for companyName: String, size: Int = 128) -> String? {
        urlCache.object(forKey: companyName.lowercased() as NSString) as String?
    }

    private func getLogoURLAsync(for domain: String) async -> String? {
        let clean = cleanDomain(domain)
        guard !clean.isEmpty else { return nil }
        if let cached = urlCache.object(forKey: clean as NSString) { return cached as String }

        // Use the Logo API (CDN) directly which has higher limits (500k/mo)
        // We prefer the icon, so we try that first
        let iconURL = "https://asset.brandfetch.io/\(clean)?types=icon"

        // We verify if the icon exists by making a HEAD request or just returning it and letting the image loader handle 404s.
        // For simplicity and speed in this specific service, we will trust the CDN to return something or handle the error in the image download.
        // However, to be robust, we can try to fetch the icon, if it fails, fallback to logo (default).

        // Let's return the icon URL first. The `fetchLogo` method can handle the fallback if the image download fails.
        // Actually, to keep it simple: just return the base URL and let the fetcher decide params, or return the likely best one.
        // User wants ICON.
        return iconURL
    }

    func fetchLogo(for companyName: String, size: Int = 128) async -> UIImage? {
        let key = "\(companyName.lowercased())_\(size)" as NSString
        if let cached = cache.object(forKey: key) {
            print("🟢 [Brandfetch] Cache hit for: \(companyName)")
            return cached
        }

        // Use intelligent search first (Search API is free/high limit)
        let domain: String
        if let searchDomain = await searchBrand(query: companyName) {
            print("🎯 [Brandfetch] Search found domain: \(searchDomain) for query: \(companyName)")
            domain = searchDomain
        } else {
            domain = nameToDomain(companyName)
            print("⚠️ [Brandfetch] Search failed, fallback to guessed domain: \(domain)")
        }

        print("🔍 [Brandfetch] Fetching logo for: \(companyName) -> Domain: \(domain)")

        // Try to fetch Icon first
        // User provided Client ID: 1idrjASAupLrprMSzYV
        let clientId = "1idrjASAupLrprMSzYV"
        let iconURLString = "https://cdn.brandfetch.io/\(domain)?types=icon&c=\(clientId)"
        // Fallback to default (logo) if icon fails or returns 404
        let logoURLString = "https://cdn.brandfetch.io/\(domain)?c=\(clientId)"

        if let image = await downloadImage(urlString: iconURLString) {
            print("✅ [Brandfetch] downloaded ICON for: \(companyName)")
            cache.setObject(image, forKey: key, cost: 100)  // approx cost
            urlCache.setObject(
                iconURLString as NSString, forKey: companyName.lowercased() as NSString)
            return image
        } else if let image = await downloadImage(urlString: logoURLString) {
            print("✅ [Brandfetch] downloaded LOGO (fallback) for: \(companyName)")
            cache.setObject(image, forKey: key, cost: 100)
            urlCache.setObject(
                logoURLString as NSString, forKey: companyName.lowercased() as NSString)
            return image
        }

        print("❌ [Brandfetch] All downloads failed for: \(domain)")
        return nil
    }

    private func downloadImage(urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                let image = UIImage(data: data)
            {
                return image
            }
        } catch {}
        return nil
    }

    func fetchLogoForReceipt(_ receipt: Receipt) async -> (UIImage, [Color]) {
        let query = receipt.logo_search_term ?? receipt.store_name
        print(
            "🧐 [Brandfetch] Processing receipt for store: '\(receipt.store_name)' using query: '\(query)'"
        )
        let (image, colors) = await fetchLogoAndColors(for: query)
        if image == nil { print("⚠️ [Brandfetch] Using placeholder for: \(receipt.store_name)") }
        return (image ?? generatePlaceholderImage(for: receipt.store_name), colors)
    }

    func fetchLogoAndColors(for storeName: String) async -> (UIImage?, [Color]) {
        let key = storeName.lowercased() as NSString
        if let img = cache.object(forKey: key),
            let cols = colorCache.object(forKey: key) as? [Color]
        {
            return (img, cols)
        }

        let domain: String
        let searchDomain = await searchBrand(query: storeName)
        if let searchDomain = searchDomain {
            print("🎯 [Brandfetch] Search found domain: \(searchDomain) for query: \(storeName)")
            domain = searchDomain
        } else {
            domain = nameToDomain(storeName)
            print("⚠️ [Brandfetch] Search failed, fallback to guessed domain: \(domain)")
        }

        // Try Icon first, then Logo
        let clientId = "1idrjASAupLrprMSzYV"
        let iconURLString = "https://cdn.brandfetch.io/\(domain)?types=icon&c=\(clientId)"
        let logoURLString = "https://cdn.brandfetch.io/\(domain)?c=\(clientId)"

        var logo: UIImage? = await downloadImage(urlString: iconURLString)
        var validURL = iconURLString

        if logo == nil {
            logo = await downloadImage(urlString: logoURLString)
            validURL = logoURLString
        }

        if logo != nil {
            urlCache.setObject(validURL as NSString, forKey: key)
        }

        var colors: [Color] = []
        // With direct Logo API, we don't get colors automatically. We generate them.
        // Or if we really needed them, we'd have to use Brand API which is limited.
        // Strategy: Use generated colors from name as fallback, which is fine.
        colors = generateColors(for: storeName)

        if let logo = logo { cache.setObject(logo, forKey: key) }
        colorCache.setObject(colors as NSArray, forKey: key)
        return (logo, colors)
    }

    private func searchBrand(query: String) async -> String? {
        // Brandfetch Search API
        guard
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "\(baseURL)/search/\(encodedQuery)")
        else { return nil }

        print("🔎 [Brandfetch] Searching API: \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResp = response as? HTTPURLResponse else { return nil }

            if httpResp.statusCode != 200 {
                print("⚠️ [Brandfetch] Search API returned status: \(httpResp.statusCode)")
                if let str = String(data: data, encoding: .utf8) { print("   Response: \(str)") }
                return nil
            }

            // Response is an array of brand objects
            if let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                let firstResult = results.first,
                let domain = firstResult["domain"] as? String
            {
                return domain
            } else {
                print("⚠️ [Brandfetch] No results found in search for: \(query)")
            }
        } catch {
            print("❌ [Brandfetch] Search network error: \(error)")
        }
        return nil
    }

    // Brand API fetchBrandData removed to use high-limit Logo API instead.

    private func nameToDomain(_ name: String) -> String {
        let cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "&", with: "and").replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        let result = cleaned.contains(".") ? cleaned : "\(cleaned).com"
        print("🧠 [Brandfetch] Guessed domain: \(result) from name: \(name)")
        return result
    }

    private func cleanDomain(_ domain: String) -> String {
        var clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "").replacingOccurrences(
                of: "http://", with: ""
            ).replacingOccurrences(of: "www.", with: "")
        if clean.hasSuffix("/") { clean = String(clean.dropLast()) }
        let result = clean.contains(".") ? clean : "\(clean).com"
        return result
    }

    private func generateColors(for storeName: String) -> [Color] {
        let h = Double(abs(storeName.lowercased().hashValue) % 360) / 360.0
        return [
            Color(hue: h, saturation: 0.6, brightness: 0.8),
            Color(hue: h, saturation: 0.5, brightness: 0.7),
            Color(hue: h, saturation: 0.4, brightness: 0.6),
        ]
    }

    func generatePlaceholderImage(
        for storeName: String, size: CGSize = CGSize(width: 100, height: 100)
    ) -> UIImage {
        let colors = generateColors(for: storeName)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(colors[0]).cgColor, UIColor(colors[1]).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let initials = getInitials(from: storeName)
            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.4, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let sz = initials.size(withAttributes: attr)
            initials.draw(
                in: CGRect(
                    x: (size.width - sz.width) / 2, y: (size.height - sz.height) / 2,
                    width: sz.width, height: sz.height), withAttributes: attr)
        }
    }

    private func getInitials(from name: String) -> String {
        let words = name.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count >= 2 { return String(words[0].prefix(1) + words[1].prefix(1)).uppercased() }
        return String(words.first?.prefix(2) ?? "?").uppercased()
    }

    func clearCache() {
        cache.removeAllObjects()
        colorCache.removeAllObjects()
        urlCache.removeAllObjects()
    }
}

enum BrandfetchError: Error {
    case invalidURL, invalidResponse, invalidJSON
    case apiError(statusCode: Int)
}
