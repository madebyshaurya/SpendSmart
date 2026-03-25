import Foundation
import SwiftUI
import UIKit

class BackendAPIService {
    static let shared = BackendAPIService()
    private let backendSecretKey = secretKey
    private var cachedBaseURL: String?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    private lazy var aiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    private var authToken: String? {
        didSet {
            if let token = authToken {
                KeychainService.save(token, forKey: "backend_auth_token")
            } else {
                KeychainService.delete(forKey: "backend_auth_token")
            }
        }
    }

    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                KeychainService.save(token, forKey: "backend_refresh_token")
            } else {
                KeychainService.delete(forKey: "backend_refresh_token")
            }
        }
    }

    private init() {
        // Migrate from UserDefaults to Keychain (one-time)
        if let oldAuth = UserDefaults.standard.string(forKey: "backend_auth_token") {
            KeychainService.save(oldAuth, forKey: "backend_auth_token")
            UserDefaults.standard.removeObject(forKey: "backend_auth_token")
        }
        if let oldRefresh = UserDefaults.standard.string(forKey: "backend_refresh_token") {
            KeychainService.save(oldRefresh, forKey: "backend_refresh_token")
            UserDefaults.standard.removeObject(forKey: "backend_refresh_token")
        }
        self.authToken = KeychainService.get(forKey: "backend_auth_token")
        self.refreshToken = KeychainService.get(forKey: "backend_refresh_token")
    }

    private func getBaseURL() async -> String {
        if let cached = cachedBaseURL { return cached }
        let baseURL = await BackendConfig.shared.activeBackendURL
        let defaults = UserDefaults.standard
        if let previous = defaults.string(forKey: "backend_base_url"), previous != baseURL {
            self.authToken = nil
            self.refreshToken = nil
        }
        defaults.set(baseURL, forKey: "backend_base_url")
        cachedBaseURL = baseURL
        return baseURL
    }

    // MARK: - AI & Receipts

    func generateAIContent(
        prompt: String, image: UIImage? = nil, systemInstruction: String? = nil,
        config: [String: Any]? = nil
    ) async throws -> String {
        var body: [String: Any] = ["prompt": prompt]
        if let sys = systemInstruction { body["systemInstruction"] = sys }
        if let conf = config { body["config"] = conf }
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            body["image"] = "data:image/jpeg;base64,\(data.base64EncodedString())"
        }

        let res: AIBackendResponse = try await makeRequest(
            endpoint: "/api/ai/generate", method: "POST", body: body)
        return res.response.text
    }

    func processReceipt(images: [UIImage]) async throws -> ReceiptProcessingResponse {
        var imageDataArray: [String] = []
        for image in images {
            let isEnhanced = await image.accessibilityHint == "enhanced_receipt"
            let maxDimension: CGFloat = isEnhanced ? 2000 : 1600
            let scaled = resizeImage(image, maxDimension: maxDimension)
            let quality: CGFloat = isEnhanced ? 0.75 : 0.65
            if let data = scaled.jpegData(compressionQuality: quality) {
                imageDataArray.append("data:image/jpeg;base64,\(data.base64EncodedString())")
            }
        }
        guard !imageDataArray.isEmpty else { throw BackendAPIError.imageProcessingFailed }

        let body = ["images": imageDataArray]
        return try await makeRequest(
            endpoint: "/api/ai/process-receipt", method: "POST", body: body, requiresAuth: true)
    }

    // MARK: - Image Upload

    func uploadImages(_ images: [UIImage]) async throws -> BulkImageUploadResponse {
        let imageData = images.compactMap {
            let scaled = resizeImage($0, maxDimension: 1600)
            return scaled.jpegData(compressionQuality: 0.65)?.base64EncodedString()
        }
        let body = ["images": imageData.map { "data:image/jpeg;base64,\($0)" }]
        return try await makeRequest(
            endpoint: "/api/images/upload-multiple", method: "POST", body: body, requiresAuth: true)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Chat with AI about expenses
    /// - Parameters:
    ///   - message: The user's message
    ///   - history: Previous conversation history
    ///   - forceCharts: If true, AI will always include a chart in response
    /// - Returns: ChatAPIResponse with text and optional chart
    func chatWithExpenses(message: String, history: [[String: String]] = [], forceCharts: Bool = false) async throws -> ChatAPIResponse
    {
        let body: [String: Any] = [
            "message": message,
            "conversationHistory": history,
            "forceCharts": forceCharts,
        ]

        let response: ChatAPIResponse = try await makeRequest(
            endpoint: "/api/chat/analyze", method: "POST", body: body, requiresAuth: true)
        return response
    }

    func fetchServerSubscriptionStatus() async throws -> SubscriptionStatusPayload {
        let response: SubscriptionStatusResponse = try await makeRequest(
            endpoint: "/api/subscriptions/status", method: "GET", body: nil, requiresAuth: true)
        return response.data
    }

    func deleteAccount() async throws {
        // Backward/forward compatible with both backend route layouts:
        // - Newer:  DELETE /api/account
        // - Older:  DELETE /api/auth/account
        let endpoints = ["/api/account", "/api/auth/account"]
        var lastError: Error?

        for endpoint in endpoints {
            do {
                let _: EmptyResponse = try await makeRequest(
                    endpoint: endpoint,
                    method: "DELETE",
                    body: nil,
                    requiresAuth: true
                )
                return
            } catch let e as BackendAPIError {
                lastError = e
                if case .unknownError(let code) = e, code == 404 { continue }
                throw e
            } catch {
                lastError = error
                throw error
            }
        }

        if let lastError { throw lastError }
    }

    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false,
        useSecretKey: Bool = false,
        useAISession: Bool = false,
        allowAuthRetry: Bool = true
    ) async throws -> T {
        let baseURL = await getBaseURL()
        guard let url = URL(string: baseURL + endpoint) else { throw BackendAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = await getCurrentAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if useSecretKey {
            request.setValue(backendSecretKey, forHTTPHeaderField: "X-API-Key")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await (useAISession ? aiSession : session).data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 && requiresAuth && allowAuthRetry {
            self.authToken = nil
            await syncAuthTokenFromSupabase()
            return try await makeRequest(
                endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth,
                useSecretKey: useSecretKey, useAISession: useAISession, allowAuthRetry: false)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw BackendAPIError.unknownError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func makeRequest(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false,
        useSecretKey: Bool = false,
        allowAuthRetry: Bool = true
    ) async throws -> [String: Any] {
        let baseURL = await getBaseURL()
        guard let url = URL(string: baseURL + endpoint) else { throw BackendAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = await getCurrentAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 && requiresAuth && allowAuthRetry {
            self.authToken = nil
            await syncAuthTokenFromSupabase()
            return try await makeRequest(
                endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth,
                useSecretKey: useSecretKey, allowAuthRetry: false)
        }

        guard 200...299 ~= httpResponse.statusCode else { throw BackendAPIError.serverError }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func syncAuthTokenFromSupabase() async {
        if let current = authToken, !current.isEmpty { return }
        self.authToken = await SupabaseManager.shared.getAuthToken()
    }

    func getCurrentAuthToken() async -> String? {
        if let stored = authToken, !stored.isEmpty { return stored }
        let token = await SupabaseManager.shared.getAuthToken()
        if token != authToken { self.authToken = token }
        return token
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let data: AuthData
}

struct AuthData: Codable {
    let user: BackendUser?
    let session: Session?
}

struct BackendUser: Codable {
    let id: String
    let email: String?
}

struct Session: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct SubscriptionStatusResponse: Codable {
    let success: Bool?
    let data: SubscriptionStatusPayload
}

struct SubscriptionStatusPayload: Codable {
    let isSubscribed: Bool
    let subscriptionTier: String?
    let subscriptionExpiresAt: Date?
    let hasCloudAccess: Bool?

    enum CodingKeys: String, CodingKey {
        case isSubscribed = "is_subscribed"
        case subscriptionTier = "subscription_tier"
        case subscriptionExpiresAt = "subscription_expires_at"
        case hasCloudAccess = "has_cloud_access"
    }
}

struct ReceiptProcessingResponse: Codable {
    let isValid: Bool
    let message: String?
    let store_name: String?
    let purchase_date: String?
    let total_amount: Double?
    let currency: String?
    let items: [BackendReceiptProcessingItem]?
    let total_tax: Double?
    let payment_method: String?
    let store_address: String?
    let receipt_name: String?
    let logo_search_term: String?
}

struct BackendReceiptProcessingItem: Codable {
    let name: String
    let price: Double
    let category: String
    let isDiscount: Bool
    let originalPrice: Double?
}

struct AIBackendResponse: Codable {
    struct Response: Codable { let text: String }
    let response: Response
}

struct ReceiptValidationResponse: Codable {
    let isValid: Bool
    let confidence: Double
    let message: String
    let missingElements: [String]
}

struct AIStreamingResponse: Codable {
    struct Content: Codable { let text: String }
    let response: Content
}

struct ImageUploadResponse: Codable {
    let url: String
}

struct BulkImageUploadResponse: Codable {
    struct ImageResult: Codable {
        let url: String
        let success: Bool
    }
    let images: [ImageResult]
}

struct EmptyResponse: Codable {
    let success: Bool?
}

enum BackendAPIError: Error, LocalizedError {
    case invalidURL, encodingFailed, decodingFailed
    case networkError(Error)
    case invalidResponse, unauthorized, serverError
    case unknownError(Int)
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Unauthorized"
        case .serverError: return "Server error"
        case .imageProcessingFailed: return "Failed to process image"
        default: return "Backend error"
        }
    }
}
