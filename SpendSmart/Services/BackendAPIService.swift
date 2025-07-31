//
//  BackendAPIService.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-07-29.
//

import Foundation
import UIKit

// MARK: - Helper Types

/// Helper for decoding Any values from JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// A service for communicating with the SpendSmart backend API
class BackendAPIService {
    static let shared = BackendAPIService()

    // Backend configuration (dynamically determined)
    private let backendSecretKey = secretKey // From APIKeys.swift
    private var cachedBaseURL: String?

    // Session configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // Current user token (stored after authentication)
    private var authToken: String? {
        didSet {
            // Persist auth token to UserDefaults
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "backend_auth_token")
                print("🔐 [iOS] Auth token saved to UserDefaults")
            } else {
                UserDefaults.standard.removeObject(forKey: "backend_auth_token")
                print("🔐 [iOS] Auth token removed from UserDefaults")
            }
        }
    }

    private init() {
        print("🔧 [iOS] BackendAPIService initialized with dynamic backend detection")
        print("🔑 [iOS] Secret Key configured: \(!backendSecretKey.isEmpty)")

        // Restore auth token from UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: "backend_auth_token") {
            self.authToken = savedToken
            print("🔐 [iOS] Auth token restored from UserDefaults")
        }
    }

    /// Get the current base URL (with automatic backend detection)
    private func getBaseURL() async -> String {
        if let cached = cachedBaseURL {
            return cached
        }

        let backendURL = await BackendConfig.shared.activeBackendURL
        let baseURL = backendURL
        cachedBaseURL = baseURL

        print("🔗 [iOS] Active Backend URL: \(baseURL)")
        print("🏠 [iOS] Using localhost: \(BackendConfig.shared.isUsingLocalhost)")

        return baseURL
    }
    
    // MARK: - Authentication Methods
    
    /// Sign in with Apple ID token
    func signInWithApple(idToken: String) async throws -> AuthResponse {
        let endpoint = "/api/auth/apple-signin"
        let body = [
            "idToken": idToken,
            "provider": "apple"
        ]
        
        let response: AuthResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        // Store the auth token and user info for future requests
        self.authToken = response.data.session?.accessToken

        // Store user email for session restoration
        if let userEmail = response.data.user?.email {
            UserDefaults.standard.set(userEmail, forKey: "backend_user_email")
            print("📧 [iOS] User email saved to UserDefaults: \(userEmail)")
        }

        return response
    }
    
    /// Create a guest user account
    func createGuestAccount() async throws -> AuthResponse {
        let endpoint = "/api/auth/guest-signin"
        
        let response: AuthResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: false
        )
        
        // Store the auth token and user info for future requests
        self.authToken = response.data.session?.accessToken

        // Store user email for session restoration (guest users don't have email)
        if let userEmail = response.data.user?.email {
            UserDefaults.standard.set(userEmail, forKey: "backend_user_email")
            print("📧 [iOS] User email saved to UserDefaults: \(userEmail)")
        } else {
            UserDefaults.standard.set("Guest User", forKey: "backend_user_email")
            print("📧 [iOS] Guest user session saved to UserDefaults")
        }

        return response
    }
    
    /// Sign out the current user
    func signOut() async throws {
        let endpoint = "/api/auth/signout"
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: true
        )
        
        // Clear the stored auth token and user info
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "backend_user_email")
        print("🔐 [iOS] User session cleared from UserDefaults")
    }
    
    /// Delete the current user's account
    func deleteAccount() async throws {
        let endpoint = "/api/auth/account"
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: endpoint,
            method: "DELETE",
            body: [:],
            requiresAuth: true
        )
        
        // Clear the stored auth token and user info
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "backend_user_email")
        print("🔐 [iOS] User session cleared from UserDefaults")
    }
    
    /// Delete a guest account by user ID
    func deleteGuestAccount(userId: String) async throws {
        let endpoint = "/api/auth/guest-account/\(userId)"
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: endpoint,
            method: "DELETE",
            body: [:],
            requiresAuth: false,
            useSecretKey: true
        )
    }
    
    // MARK: - AI Methods
    
    /// Generate content using AI
    func generateAIContent(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil,
        config: [String: Any]? = nil
    ) async throws -> AIContentResponse {
        let endpoint = "/api/ai/generate"
        
        var body: [String: Any] = [
            "prompt": prompt
        ]
        
        if let systemInstruction = systemInstruction {
            body["systemInstruction"] = systemInstruction
        }
        
        if let config = config {
            body["config"] = config
        }
        
        // Convert image to base64 if provided
        if let image = image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw BackendAPIError.imageProcessingFailed
            }
            let base64Image = imageData.base64EncodedString()
            body["image"] = "data:image/jpeg;base64,\(base64Image)"
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
    }
    
    /// Validate a receipt using AI
    func validateReceipt(image: UIImage) async throws -> ReceiptValidationResponse {
        let endpoint = "/api/ai/validate-receipt"
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw BackendAPIError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        let body = [
            "image": "data:image/jpeg;base64,\(base64Image)"
        ]
        
        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
    }
    
    // MARK: - Image Upload Methods
    
    /// Upload an image to the backend
    func uploadImage(_ image: UIImage) async throws -> ImageUploadResponse {
        let endpoint = "/api/images/upload"
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw BackendAPIError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        let body = [
            "image": "data:image/jpeg;base64,\(base64Image)"
        ]
        
        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    /// Upload multiple images to the backend
    func uploadImages(_ images: [UIImage]) async throws -> MultipleImageUploadResponse {
        let endpoint = "/api/images/upload-multiple"
        
        var base64Images: [String] = []
        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw BackendAPIError.imageProcessingFailed
            }
            let base64Image = imageData.base64EncodedString()
            base64Images.append("data:image/jpeg;base64,\(base64Image)")
        }
        
        let body = [
            "images": base64Images
        ]
        
        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    // MARK: - Core Networking Methods

    /// Make a generic API request
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        requiresAuth: Bool = false,
        useSecretKey: Bool = false
    ) async throws -> T {

        // Get the dynamic base URL
        let baseURL = await getBaseURL()

        print("🚀 [iOS] ===== API REQUEST START =====")
        print("📱 [iOS] Making API request: \(method) \(endpoint)")
        print("🔗 [iOS] Base URL: \(baseURL)")
        print("🎯 [iOS] Full URL: \(baseURL + endpoint)")
        print("🔐 [iOS] Requires Auth: \(requiresAuth)")
        print("🔑 [iOS] Uses Secret Key: \(useSecretKey)")
        print("📦 [iOS] Has Body: \(body != nil)")

        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ [iOS] Invalid URL: \(baseURL + endpoint)")
            throw BackendAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication headers
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 [iOS] Added Bearer token to request")
        } else if requiresAuth {
            print("⚠️ [iOS] Auth required but no token available")
        }

        if useSecretKey {
            request.setValue(backendSecretKey, forHTTPHeaderField: "X-API-Key")
            print("🔑 [iOS] Added secret key to request")
        }

        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                print("📦 [iOS] Request body added: \(body)")
            } catch {
                print("❌ [iOS] Failed to encode request body: \(error)")
                throw BackendAPIError.encodingFailed
            }
        }

        print("🌐 [iOS] Starting network request...")
        print("⏱️ [iOS] Request timeout: \(request.timeoutInterval) seconds")

        // Make the request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [iOS] Invalid HTTP response for \(endpoint)")
                throw BackendAPIError.invalidResponse
            }

            print("📡 [iOS] Response received!")
            print("📱 [iOS] Response status: \(httpResponse.statusCode) for \(endpoint)")
            print("📊 [iOS] Response headers: \(httpResponse.allHeaderFields)")
            print("📦 [iOS] Response data size: \(data.count) bytes")

            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [iOS] Response body: \(responseString)")
            }

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode the response
                print("✅ [iOS] Request successful: \(endpoint)")
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    print("🎉 [iOS] Successfully decoded response for \(endpoint)")
                    return decodedResponse
                } catch {
                    print("❌ [iOS] Decoding error for \(endpoint): \(error)")
                    print("🔍 [iOS] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    throw BackendAPIError.decodingFailed
                }

            case 400:
                print("❌ [iOS] Bad request: \(endpoint)")
                throw BackendAPIError.badRequest
            case 401:
                print("❌ [iOS] Unauthorized: \(endpoint)")
                throw BackendAPIError.unauthorized
            case 403:
                print("❌ [iOS] Forbidden: \(endpoint)")
                throw BackendAPIError.forbidden
            case 404:
                print("❌ [iOS] Not found: \(endpoint)")
                throw BackendAPIError.notFound
            case 429:
                print("❌ [iOS] Rate limited: \(endpoint)")
                throw BackendAPIError.rateLimited
            case 500...599:
                print("❌ [iOS] Server error: \(endpoint)")
                throw BackendAPIError.serverError
            default:
                print("❌ [iOS] Unknown error \(httpResponse.statusCode): \(endpoint)")
                throw BackendAPIError.unknownError(httpResponse.statusCode)
            }

        } catch let error as BackendAPIError {
            print("🔄 [iOS] Re-throwing BackendAPIError: \(error)")
            throw error
        } catch {
            print("💥 [iOS] ===== NETWORK ERROR DETAILS =====")
            print("❌ [iOS] Network error for \(endpoint): \(error.localizedDescription)")
            print("🔍 [iOS] Error type: \(type(of: error))")
            print("📋 [iOS] Full error: \(error)")

            if let urlError = error as? URLError {
                print("🌐 [iOS] URLError code: \(urlError.code.rawValue)")
                print("🌐 [iOS] URLError description: \(urlError.localizedDescription)")

                switch urlError.code {
                case .cannotConnectToHost:
                    print("🚫 [iOS] Cannot connect to host - server may be down")
                case .timedOut:
                    print("⏰ [iOS] Request timed out")
                case .networkConnectionLost:
                    print("📡 [iOS] Network connection lost")
                case .notConnectedToInternet:
                    print("🌐 [iOS] Not connected to internet")
                default:
                    print("❓ [iOS] Other URL error: \(urlError.code)")
                }
            }
            print("=======================================")
            throw BackendAPIError.networkError(error)
        }
    }

    /// Set the authentication token manually (for testing or manual token management)
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Force refresh backend detection (useful for testing or when network conditions change)
    func refreshBackendConnection() async {
        print("🔄 [iOS] Forcing backend connection refresh...")
        cachedBaseURL = nil
        let newURL = await getBaseURL()
        print("🔗 [iOS] Backend connection refreshed to: \(newURL)")
    }

    /// Get current backend status for debugging
    func getBackendStatus() async -> (url: String, isLocalhost: Bool) {
        let url = await getBaseURL()
        return (url, BackendConfig.shared.isUsingLocalhost)
    }

    /// Get the current authentication token
    func getAuthToken() -> String? {
        return authToken
    }

    /// Check if the user is currently authenticated
    func isAuthenticated() -> Bool {
        guard !backendSecretKey.isEmpty else {
            print("⚠️ [iOS] Backend API not configured, treating as not authenticated")
            return false
        }
        return authToken != nil
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let success: Bool
    let data: AuthData
    let message: String?
    let timestamp: String
}

struct AuthData: Codable {
    let user: BackendUser?
    let session: Session?
}

struct BackendUser: Codable {
    let id: String
    let email: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

struct Session: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

struct ReceiptsResponse: Codable {
    let success: Bool
    let data: ReceiptsData
    let message: String?
    let timestamp: String
}

struct ReceiptsData: Codable {
    let receipts: [[String: Any]]
    let pagination: Pagination?

    enum CodingKeys: String, CodingKey {
        case receipts
        case pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode receipts as raw dictionaries first
        let receiptsArray = try container.decode([AnyCodable].self, forKey: .receipts)
        self.receipts = receiptsArray.compactMap { $0.value as? [String: Any] }

        self.pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Note: Encoding not implemented as this is primarily for decoding responses
        try container.encode(pagination, forKey: .pagination)
    }
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case totalPages // Backend sends "totalPages" in camelCase
    }
}

struct ReceiptResponse: Codable {
    let success: Bool
    let data: ReceiptData
    let message: String?
    let timestamp: String
}

struct ReceiptData: Codable {
    let receipt: Receipt
}

struct AIContentResponse: Codable {
    let success: Bool
    let data: AIContentData
    let message: String?
    let timestamp: String
}

struct AIContentData: Codable {
    let response: String
}

struct ReceiptValidationResponse: Codable {
    let success: Bool
    let data: ReceiptValidationData
    let message: String?
    let timestamp: String
}

struct ReceiptValidationData: Codable {
    let isValid: Bool
    let confidence: Double
    let message: String
    let missingElements: [String]

    enum CodingKeys: String, CodingKey {
        case isValid
        case confidence
        case message
        case missingElements = "missing_elements"
    }
}

struct ImageUploadResponse: Codable {
    let success: Bool
    let data: ImageUploadData
    let message: String?
    let timestamp: String
}

struct ImageUploadData: Codable {
    let url: String
    let provider: String
}

struct MultipleImageUploadResponse: Codable {
    let success: Bool
    let data: MultipleImageUploadData
    let message: String?
    let timestamp: String
}

struct MultipleImageUploadData: Codable {
    let urls: [String]
    let provider: String
}

struct EmptyResponse: Codable {
    let success: Bool
    let message: String?
    let timestamp: String
}

// MARK: - Error Types

enum BackendAPIError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed
    case networkError(Error)
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case unknownError(Int)
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingFailed:
            return "Failed to encode request"
        case .decodingFailed:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not found"
        case .rateLimited:
            return "Rate limited"
        case .serverError:
            return "Server error"
        case .unknownError(let code):
            return "Unknown error (status code: \(code))"
        case .imageProcessingFailed:
            return "Failed to process image"
        }
    }
}
