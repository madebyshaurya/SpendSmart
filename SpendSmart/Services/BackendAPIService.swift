//
//  BackendAPIService.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-07-29.
//

import Foundation
import UIKit
import SwiftUI

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

    // Global log level for network chatter
    enum LogLevel { case verbose, summary }
    private let logLevel: LogLevel = .summary

    // Session configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // Increased from 30 to 60 seconds
        config.timeoutIntervalForResource = 120 // Increased from 60 to 120 seconds for AI processing
        return URLSession(configuration: config)
    }()
    
    // AI-specific session with longer timeout
    private lazy var aiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90  // Longer timeout for AI requests
        config.timeoutIntervalForResource = 180 // 3 minutes for AI processing
        return URLSession(configuration: config)
    }()

    // MARK: - Logging helpers
    /// Redacts large base64 image strings from request bodies printed to console
    private func sanitizeBodyForLog(_ body: Any?) -> Any {
        guard let body = body else { return "nil" }

        // Dictionary case
        if let dict = body as? [String: Any] {
            var sanitized: [String: Any] = [:]
            for (key, value) in dict {
                let lowerKey = key.lowercased()
                if lowerKey == "image" {
                    if let s = value as? String { sanitized[key] = "[image base64 redacted (\(s.count) chars)]" } else { sanitized[key] = "[image redacted]" }
                } else if lowerKey == "images", let arr = value as? [Any] {
                    sanitized[key] = arr.map { item -> Any in
                        if let s = item as? String, s.hasPrefix("data:image") { return "[image base64 redacted (\(s.count) chars)]" }
                        return item
                    }
                } else if let s = value as? String, s.hasPrefix("data:image") {
                    sanitized[key] = "[image base64 redacted (\(s.count) chars)]"
                } else {
                    sanitized[key] = value
                }
            }
            return sanitized
        }

        // Array case
        if let arr = body as? [Any] {
            return arr.map { sanitizeBodyForLog($0) }
        }

        // String case
        if let s = body as? String, s.hasPrefix("data:image") {
            return "[image base64 redacted (\(s.count) chars)]"
        }

        return body
    }

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

        // Detect environment switch and clear stale tokens if needed
        let defaults = UserDefaults.standard
        let previousBaseURL = defaults.string(forKey: "backend_base_url")
        if let previous = previousBaseURL, previous != baseURL {
            print("⚠️ [iOS] Backend base URL changed (\(previous) -> \(baseURL)). Clearing stored auth token to avoid invalid token errors.")
            self.authToken = nil
        }
        defaults.set(baseURL, forKey: "backend_base_url")

        cachedBaseURL = baseURL

        print("🔗 [iOS] Active Backend URL: \(baseURL)")
        print("🏠 [iOS] Using localhost: \(BackendConfig.shared.isUsingLocalhost)")

        return baseURL
    }
    
    // MARK: - Authentication Methods
    
    /// Sign in with Apple ID token
    func signInWithApple(idToken: String, userEmail: String? = nil) async throws -> AuthResponse {
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

        // Store user email for session restoration - prioritize Apple credential email
        if let email = userEmail, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "backend_user_email")
            print("📧 [iOS] Apple credential email saved to UserDefaults: \(email)")
        } else if let userEmail = response.data.user?.email, !userEmail.isEmpty {
            UserDefaults.standard.set(userEmail, forKey: "backend_user_email")
            print("📧 [iOS] Backend user email saved to UserDefaults: \(userEmail)")
        } else {
            UserDefaults.standard.set("Apple ID User", forKey: "backend_user_email")
            print("📧 [iOS] Apple ID user session saved to UserDefaults (no email)")
        }

        return response
    }
    
    /// Create a guest user account
    func createGuestAccount() async throws -> AuthResponse {
        let endpoint = "/api/auth/guest-signin"
        
        print("🔐 [iOS] Creating guest account via backend API...")
        
        let response: AuthResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: false
        )
        
        // Store the auth token and user info for future requests
        self.authToken = response.data.session?.accessToken
        print("🔐 [iOS] Guest account created successfully!")
        print("🔐 [iOS] Auth token stored: \(response.data.session?.accessToken.prefix(20) ?? "nil")...")
        print("🔐 [iOS] User ID: \(response.data.user?.id ?? "nil")")

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
        
        // Use a generic response type to handle the nested JSON structure
        let response: [String: Any] = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false,
            useAISession: true
        )
        
        // Extract the text field from the response
        guard let responseData = response["response"] as? [String: Any],
              let text = responseData["text"] as? String else {
            throw BackendAPIError.decodingFailed
        }
        
        return AIContentResponse(response: AIContentData(text: text))
    }
    
    /// Generate AI content with streaming support
    func generateAIContentWithStreaming(
        prompt: String,
        image: UIImage? = nil,
        systemInstruction: String? = nil,
        config: [String: Any]? = nil,
        progressHandler: @escaping (AIStreamingProgress) -> Void
    ) async throws -> AIContentResponse {
        let endpoint = "/api/ai/generate-streaming"
        
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
        
        // Get the dynamic base URL
        let baseURL = await getBaseURL()
        guard let url = URL(string: baseURL + endpoint) else {
            throw BackendAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Add auth header for protected AI streaming endpoint
        if let token = await SupabaseManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw BackendAPIError.encodingFailed
        }
        
        // Use AI session for longer timeout
        let (data, response) = try await aiSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw BackendAPIError.serverError
        }
        
        // Parse streaming response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let lines = responseString.components(separatedBy: "\n")
        
        var fullText = ""
        var currentProgress = AIStreamingProgress(
            stage: .initializing,
            progress: 0.0,
            message: "Initializing AI processing...",
            partialText: ""
        )
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))
                
                if data == "[DONE]" {
                    // Processing complete
                    currentProgress = AIStreamingProgress(
                        stage: .complete,
                        progress: 1.0,
                        message: "Processing complete!",
                        partialText: fullText
                    )
                    progressHandler(currentProgress)
                    break
                }
                
                // Parse JSON data
                if let jsonData = data.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    if let stage = json["stage"] as? String,
                       let progress = json["progress"] as? Double,
                       let message = json["message"] as? String {
                        
                        let streamingStage = AIStreamingStage(rawValue: stage) ?? .processing
                        let partialText = json["partialText"] as? String ?? ""
                        
                        if !partialText.isEmpty {
                            fullText += partialText
                        }
                        
                        currentProgress = AIStreamingProgress(
                            stage: streamingStage,
                            progress: progress,
                            message: message,
                            partialText: fullText
                        )
                        
                        progressHandler(currentProgress)
                    }
                }
            }
        }
        
        return AIContentResponse(response: AIContentData(text: fullText))
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
        
        let resp: ReceiptValidationResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true,
            useAISession: true
        )
        // Log concise AI response JSON
        if let data = try? JSONEncoder().encode(resp),
           let json = String(data: data, encoding: .utf8) {
            print("🤖 [AI] validateReceipt response: \(json)")
        }
        return resp
    }
    
    /// Process receipt using the comprehensive AI endpoint
    func processReceipt(image: UIImage) async throws -> ReceiptProcessingResponse {
        print("🔍 [processReceipt] Starting receipt processing...")
        print("🔍 [processReceipt] Image size: \(image.size)")
        print("🔍 [processReceipt] Image scale: \(image.scale)")
        
        let endpoint = "/api/ai/process-receipt"
        
        // Use higher quality for receipt processing to improve AI accuracy
        // If the image is already enhanced (from document scanner), use max quality
        let compressionQuality: CGFloat = await image.accessibilityHint == "enhanced_receipt" ? 0.95 : 0.9
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            print("❌ [processReceipt] Failed to convert image to JPEG data")
            throw BackendAPIError.imageProcessingFailed
        }
        
        print("🔍 [processReceipt] JPEG data size: \(imageData.count) bytes")
        let base64Image = imageData.base64EncodedString()
        print("🔍 [processReceipt] Base64 string length: \(base64Image.count)")
        print("🔍 [processReceipt] Base64 preview: \(String(base64Image.prefix(50)))...")
        
        let body = [
            "image": "data:image/jpeg;base64,\(base64Image)"
        ]
        
        print("🔍 [processReceipt] Sending request to: \(endpoint)")
        print("🔍 [processReceipt] Request body keys: \(body.keys)")
        
        // Check authentication status before making request
        let authToken = await getCurrentAuthToken()
        print("🔐 [processReceipt] Auth token available: \(authToken != nil)")
        print("🔐 [processReceipt] Auth token preview: \(authToken?.prefix(20) ?? "nil")...")
        
        do {
            print("🔍 [processReceipt] Making API request...")
            let resp: ReceiptProcessingResponse = try await makeRequest(
                endpoint: endpoint,
                method: "POST",
                body: body,
                requiresAuth: true,
                useAISession: true
            )
            
            print("🔍 [processReceipt] Response received successfully")
            print("🔍 [processReceipt] Response isValid: \(resp.isValid)")
            print("🔍 [processReceipt] Response message: \(resp.message ?? "nil")")
            print("🔍 [processReceipt] Response store_name: \(resp.store_name ?? "nil")")
            print("🔍 [processReceipt] Response total_amount: \(resp.total_amount ?? 0.0)")
            print("🔍 [processReceipt] Response items count: \(resp.items?.count ?? 0)")
            
            // Log concise AI response JSON
            if let data = try? JSONEncoder().encode(resp),
               let json = String(data: data, encoding: .utf8) {
                print("🤖 [AI] processReceipt response: \(json)")
            }
            
            return resp
        } catch {
            print("❌ [processReceipt] Request failed with error: \(error)")
            print("❌ [processReceipt] Error type: \(type(of: error))")
            print("❌ [processReceipt] Error description: \(error.localizedDescription)")
            
            if let backendError = error as? BackendAPIError {
                print("❌ [processReceipt] BackendAPIError: \(backendError)")
            }
            
            throw error
        }
    }
    
    /// Process a document-scanned receipt with automatic enhancement
    /// - Parameter rawImage: Raw image from document scanner
    /// - Returns: Processed receipt response
    func processDocumentScannedReceipt(rawImage: UIImage) async throws -> ReceiptProcessingResponse {
        print("📄 [processDocumentScannedReceipt] Processing document-scanned receipt...")
        
        // Enhance the scanned image for optimal AI processing
        let enhancedImage = ReceiptImageProcessor.shared.enhanceReceiptImage(rawImage)
        
        print("📄 [processDocumentScannedReceipt] Image enhanced, processing with AI...")
        
        // Process the enhanced image using the standard receipt processing
        return try await processReceipt(image: enhancedImage)
    }
    
    /// Process gallery images with automatic document detection, stitching, and enhancement
    /// - Parameter rawImages: Images selected from photo gallery
    /// - Returns: Array of receipt processing responses
    func processGalleryReceipts(rawImages: [UIImage]) async throws -> [ReceiptProcessingResponse] {
        print("📷 [processGalleryReceipts] Processing \(rawImages.count) images from gallery...")
        
        // Process images with document detection and potential stitching
        let processedImages = await ReceiptImageProcessor.shared.processGalleryImages(rawImages)
        
        print("📷 [processGalleryReceipts] Gallery processing complete - got \(processedImages.count) processed images")
        
        // Process each enhanced image with AI
        var responses: [ReceiptProcessingResponse] = []
        for (index, image) in processedImages.enumerated() {
            do {
                print("📷 [processGalleryReceipts] Processing image \(index + 1)/\(processedImages.count) with AI...")
                let response = try await processReceipt(image: image)
                responses.append(response)
            } catch {
                print("❌ [processGalleryReceipts] Failed to process image \(index + 1): \(error)")
                // Continue processing other images even if one fails
            }
        }
        
        print("📷 [processGalleryReceipts] Successfully processed \(responses.count)/\(processedImages.count) images")
        return responses
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

    // MARK: - Subscriptions API

    func fetchSubscriptions() async throws -> [Subscription] {
        let endpoint = "/api/subscriptions"
        struct Response: Codable { let success: Bool; let data: [Subscription] }
        let resp: Response = try await makeRequest(endpoint: endpoint, method: "GET", body: nil, requiresAuth: true)
        return resp.data
    }

    func upsertSubscription(_ sub: Subscription) async throws -> Subscription {
        let endpoint = "/api/subscriptions"
        let body: [String: Any] = sub.toDictionary()
        
        print("💾 [BackendAPI] Upserting subscription: \(sub.name) (\(sub.service_name))")
        print("🔐 [BackendAPI] User ID: \(sub.user_id)")
        print("📦 [BackendAPI] Body keys: \(body.keys.sorted())")
        
        struct Response: Codable { let success: Bool; let data: Subscription }
        
        // Retry mechanism for failed requests
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("🔄 [BackendAPI] Subscription save attempt \(attempt)/3")
                let resp: Response = try await makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true)
                print("✅ [BackendAPI] Subscription saved successfully on attempt \(attempt)")
                return resp.data
            } catch {
                lastError = error
                print("❌ [BackendAPI] Subscription save failed on attempt \(attempt): \(error)")
                
                // If it's an auth error, try refreshing token before next attempt
                if attempt < 3 {
                    print("🔄 [BackendAPI] Refreshing auth token before retry...")
                    await syncAuthTokenFromSupabase()
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            }
        }
        
        throw lastError ?? BackendAPIError.networkError(NSError(domain: "BackendAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }

    func deleteSubscription(id: UUID) async throws {
        let endpoint = "/api/subscriptions/\(id.uuidString)"
        let _: [String: Any] = try await makeRequest(endpoint: endpoint, method: "DELETE", body: nil, requiresAuth: true)
    }
    
    // Debug method removed - use regular subscription endpoints instead

    // MARK: - Core Networking Methods

    /// Make a generic API request for Decodable types
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        requiresAuth: Bool = false,
        useSecretKey: Bool = false,
        useAISession: Bool = false,
        allowAuthRetry: Bool = true
    ) async throws -> T {

        // Get the dynamic base URL
        let baseURL = await getBaseURL()

        if logLevel == .verbose {
            print("🚀 [iOS] ===== API REQUEST START =====")
            print("📱 [iOS] Making API request: \(method) \(endpoint)")
            print("🔗 [iOS] Base URL: \(baseURL)")
            print("🎯 [iOS] Full URL: \(baseURL + endpoint)")
            print("🔐 [iOS] Requires Auth: \(requiresAuth)")
            print("🔑 [iOS] Uses Secret Key: \(useSecretKey)")
            print("📦 [iOS] Has Body: \(body != nil)")
            if let body = body { print("📦 [iOS] Request body (sanitized): \(sanitizeBodyForLog(body))") }
        } else {
            print("➡️ [HTTP] \(method) \(endpoint) | auth=\(requiresAuth ? "y" : "n") body=\(body != nil ? "y" : "n")")
        }

        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ [iOS] Invalid URL: \(baseURL + endpoint)")
            throw BackendAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication headers
        if requiresAuth {
            let token = await getCurrentAuthToken()
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if logLevel == .verbose { print("🔐 [iOS] Added Bearer token to request") }
            } else {
                print("⚠️ [iOS] Auth required but no token available")
            }
        }

        if useSecretKey {
            request.setValue(backendSecretKey, forHTTPHeaderField: "X-API-Key")
            if logLevel == .verbose { print("🔑 [iOS] Added secret key to request") }
        }

        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                // Avoid logging raw images
                if logLevel == .verbose { print("📦 [iOS] Request body added (sanitized): \(sanitizeBodyForLog(body))") }
            } catch {
                print("❌ [iOS] Failed to encode request body: \(error)")
                throw BackendAPIError.encodingFailed
            }
        }

        if logLevel == .verbose {
            print("🌐 [iOS] Starting network request...")
            print("⏱️ [iOS] Using AI session: \(useAISession)")
            print("⏱️ [iOS] Request timeout: \(request.timeoutInterval) seconds")
        }

        // Make the request
        do {
            let (data, response) = try await (useAISession ? aiSession : session).data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [iOS] Invalid HTTP response for \(endpoint)")
                throw BackendAPIError.invalidResponse
            }

            print("📡 [iOS] Response received!")
            print("📱 [iOS] Response status: \(httpResponse.statusCode) for \(endpoint)")
            print("📊 [iOS] Response headers: \(httpResponse.allHeaderFields)")
            print("📦 [iOS] Response data size: \(data.count) bytes")

            if let responseString = String(data: data, encoding: .utf8) {
                // If this is an AI endpoint returning large content, keep logging; otherwise this is fine
                print("📄 [iOS] Response body: \(responseString)")
            }

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse based on return type T
                print("✅ [iOS] Request successful: \(endpoint)")
                do {
                    // Decode as Codable type
                    let decoder = makeBackendJSONDecoder()
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    print("🎉 [iOS] Successfully decoded response for \(endpoint)")
                    return decodedResponse
                } catch { 
                    print("❌ [iOS] Parsing/Decoding error for \(endpoint): \(error)")
                    print("🔍 [iOS] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    throw BackendAPIError.decodingFailed
                }

            case 400:
                print("❌ [iOS] Bad request: \(endpoint)")
                throw BackendAPIError.badRequest
            case 401:
                print("❌ [iOS] Unauthorized: \(endpoint)")
                // If auth is required and we haven't retried yet, attempt to refresh auth and retry once
                if requiresAuth && allowAuthRetry {
                    print("🔄 [iOS] Attempting auth recovery and retry for 401...")
                    // Clear any stored backend token (likely from a different environment)
                    self.authToken = nil
                    // First try to sync Supabase session token
                    await self.syncAuthTokenFromSupabase()
                    // If still no token, create a new guest session against the current backend
                    if (self.authToken ?? "").isEmpty {
                        do {
                            _ = try await self.createGuestAccount()
                            print("✅ [iOS] Obtained fresh guest token; retrying request...")
                        } catch {
                            print("❌ [iOS] Failed to create guest account during auth recovery: \(error)")
                        }
                    }
                    // Retry once with refreshed token
                    return try await self.makeRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        requiresAuth: requiresAuth,
                        useSecretKey: useSecretKey,
                        useAISession: useAISession,
                        allowAuthRetry: false
                    )
                }
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
    
    /// Make a generic API request for dictionary types
    private func makeRequest(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        requiresAuth: Bool = false,
        useSecretKey: Bool = false,
        useAISession: Bool = false,
        allowAuthRetry: Bool = true
    ) async throws -> [String: Any] {

        // Get the dynamic base URL
        let baseURL = await getBaseURL()

        if logLevel == .verbose {
            print("🚀 [iOS] ===== API REQUEST START =====")
            print("📱 [iOS] Making API request: \(method) \(endpoint)")
            print("🔗 [iOS] Base URL: \(baseURL)")
            print("🎯 [iOS] Full URL: \(baseURL + endpoint)")
            print("🔐 [iOS] Requires Auth: \(requiresAuth)")
            print("🔑 [iOS] Uses Secret Key: \(useSecretKey)")
            print("📦 [iOS] Has Body: \(body != nil)")
            if let body = body { print("📦 [iOS] Request body (sanitized): \(sanitizeBodyForLog(body))") }
        } else {
            print("➡️ [HTTP] \(method) \(endpoint) | auth=\(requiresAuth ? "y" : "n") body=\(body != nil ? "y" : "n")")
        }

        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ [iOS] Invalid URL: \(baseURL + endpoint)")
            throw BackendAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            let token = await getCurrentAuthToken()
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if logLevel == .verbose { print("🔐 [iOS] Added Bearer token to request") }
            } else {
                print("⚠️ [iOS] Auth required but no token available")
            }
        }

        if useSecretKey {
            request.setValue(backendSecretKey, forHTTPHeaderField: "X-API-Key")
            if logLevel == .verbose { print("🔑 [iOS] Added secret key to request") }
        }

        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                print("❌ [iOS] Failed to serialize request body: \(error)")
                throw BackendAPIError.encodingFailed
            }
        }

        // Make the request
        do {
            let (data, response) = try await session.data(for: request)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [iOS] Invalid response type")
                throw BackendAPIError.invalidResponse
            }

            print("📈 [HTTP] \(httpResponse.statusCode) | \(endpoint)")
            if logLevel == .verbose {
                print("🔄 [iOS] Response status code: \(httpResponse.statusCode)")
                print("📋 [iOS] Response headers: \(httpResponse.allHeaderFields)")
            }

            // Handle response based on status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse as dictionary
                print("✅ [iOS] Request successful: \(endpoint)")
                do {
                    guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw BackendAPIError.decodingFailed
                    }
                    print("🎉 [iOS] Successfully parsed response as dictionary for \(endpoint)")
                    return jsonObject
                } catch {
                    print("❌ [iOS] Parsing error for \(endpoint): \(error)")
                    print("🔍 [iOS] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    throw BackendAPIError.decodingFailed
                }

            case 401:
                print("❌ [iOS] Unauthorized: \(endpoint)")
                if requiresAuth && allowAuthRetry {
                    print("🔄 [iOS] Attempting auth recovery and retry for 401 (dict)...")
                    self.authToken = nil
                    await self.syncAuthTokenFromSupabase()
                    if (self.authToken ?? "").isEmpty {
                        do {
                            _ = try await self.createGuestAccount()
                            print("✅ [iOS] Obtained fresh guest token; retrying request (dict)...")
                        } catch {
                            print("❌ [iOS] Failed to create guest account during auth recovery (dict): \(error)")
                        }
                    }
                    return try await self.makeRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        requiresAuth: requiresAuth,
                        useSecretKey: useSecretKey,
                        useAISession: useAISession,
                        allowAuthRetry: false
                    )
                }
                throw BackendAPIError.unauthorized

            default:
                // Handle error responses
                print("🚨 [iOS] API Error: \(httpResponse.statusCode)")
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔍 [iOS] Error response: \(errorString)")
                throw BackendAPIError.serverError
            }

        } catch let error as BackendAPIError {
            print("🔄 [iOS] Re-throwing BackendAPIError: \(error)")
            throw error
        } catch {
            print("💥 [iOS] ===== NETWORK ERROR DETAILS =====")
            print("❌ [iOS] Network error for \(endpoint): \(error.localizedDescription)")
            print("🔍 [iOS] Error type: \(type(of: error))")
            print("📋 [iOS] Full error: \(error)")
            print("💥 [iOS] ===== END ERROR DETAILS =====")
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
    
    /// Test backend connection and authentication
    func testBackendConnection() async -> (isConnected: Bool, isAuthenticated: Bool, error: String?) {
        print("🔍 [BackendAPI] Testing backend connection...")
        
        do {
            // Test basic health endpoint
            let baseURL = await getBaseURL()
            guard let url = URL(string: baseURL + "/health") else {
                return (false, false, "Invalid URL")
            }
            
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return (false, false, "Health check failed")
            }
            
            print("✅ [BackendAPI] Backend is reachable")
            
            // Test authenticated endpoint
            do {
                let _ = try await fetchSubscriptions()
                print("✅ [BackendAPI] Authentication is working")
                return (true, true, nil)
            } catch {
                print("❌ [BackendAPI] Authentication failed: \(error)")
                return (true, false, "Authentication failed: \(error.localizedDescription)")
            }
            
        } catch {
            print("❌ [BackendAPI] Backend connection failed: \(error)")
            return (false, false, "Connection failed: \(error.localizedDescription)")
        }
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
    
    /// Synchronize authentication token from Supabase session
    func syncAuthTokenFromSupabase() async {
        // Don't override guest tokens from backend API
        if let currentToken = authToken, !currentToken.isEmpty {
            print("🔐 [iOS] Keeping existing backend auth token (guest user)")
            return
        }
        
        let token = await SupabaseManager.shared.getAuthToken()
        self.authToken = token
        if token != nil {
            print("🔐 [iOS] Synced auth token from Supabase session")
        } else {
            print("⚠️ [iOS] Failed to sync auth token from Supabase")
        }
    }
    
    /// Get current authentication token, syncing from Supabase if needed
    func getCurrentAuthToken() async -> String? {
        // For guest users created via backend API, use the stored token
        if let storedToken = authToken, !storedToken.isEmpty {
            print("🔐 [iOS] Using stored backend auth token for guest user")
            return storedToken
        }
        
        // For regular users, sync from Supabase
        let latestToken = await SupabaseManager.shared.getAuthToken()
        if latestToken != authToken {
            self.authToken = latestToken
        }
        return latestToken
    }

    // MARK: - JSON Decoder
    private func makeBackendJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let isoWithFractional = ISO8601DateFormatter()
            isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoWithFractional.date(from: value) { return d }

            // Try ISO8601 without fractional seconds
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: value) { return d }

            // Try common Postgres timestamptz string formats (with space instead of 'T')
            let formats = [
                // Space-separated date/time, various TZ styles
                "yyyy-MM-dd HH:mm:ssX",            // +00
                "yyyy-MM-dd HH:mm:ssXX",           // +0000
                "yyyy-MM-dd HH:mm:ssXXX",          // +00:00
                "yyyy-MM-dd HH:mm:ssXXXXX",        // extended
                // Milliseconds
                "yyyy-MM-dd HH:mm:ss.SSSX",
                "yyyy-MM-dd HH:mm:ss.SSSXX",
                "yyyy-MM-dd HH:mm:ss.SSSXXX",
                "yyyy-MM-dd HH:mm:ss.SSSXXXXX",
                // Microseconds
                "yyyy-MM-dd HH:mm:ss.SSSSSSX",
                "yyyy-MM-dd HH:mm:ss.SSSSSSXX",
                "yyyy-MM-dd HH:mm:ss.SSSSSSXXX",
                "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
                // ISO T separator variants
                "yyyy-MM-dd'T'HH:mm:ssX",
                "yyyy-MM-dd'T'HH:mm:ssXX",
                "yyyy-MM-dd'T'HH:mm:ssXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
            ]

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            for f in formats {
                formatter.dateFormat = f
                if let d = formatter.date(from: value) { return d }
            }

            // Try epoch seconds if it's numeric
            if let seconds = Double(value) { return Date(timeIntervalSince1970: seconds) }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
        }
        return decoder
    }

    // MARK: - Premium Endpoints

    /// Get user's premium subscription status
    /// - Returns: PremiumEntitlement with subscription details
    func getPremiumStatus() async throws -> PremiumEntitlement {
        print("📊 [BackendAPI] Fetching premium status...")

        let endpoint = "/api/premium/status"
        let response: PremiumEntitlement = try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            body: nil,
            requiresAuth: true
        )

        print("✅ [BackendAPI] Premium status: \(response.isPremium ? "Active" : "Free")")
        return response
    }

    /// Create Stripe checkout session for subscription purchase
    /// - Parameter planType: "monthly" or "annual"
    /// - Returns: Checkout URL to open in browser
    func createStripeCheckout(planType: String) async throws -> URL {
        print("💳 [BackendAPI] Creating Stripe checkout session for plan: \(planType)...")

        let endpoint = "/api/premium/create-checkout-session"

        struct CheckoutResponse: Codable {
            let checkoutUrl: String
        }

        let response: CheckoutResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: ["planType": planType],
            requiresAuth: true
        )

        guard let checkoutURL = URL(string: response.checkoutUrl) else {
            print("❌ [BackendAPI] Invalid checkout URL: \(response.checkoutUrl)")
            throw BackendAPIError.invalidURL
        }

        print("✅ [BackendAPI] Checkout session created: \(checkoutURL)")
        return checkoutURL
    }

    /// Get Stripe Customer Portal URL for subscription management
    /// - Returns: Portal URL to open in browser
    func getStripePortalURL() async throws -> URL {
        print("🔗 [BackendAPI] Creating Stripe customer portal session...")

        let endpoint = "/api/premium/create-portal-session"

        struct PortalResponse: Codable {
            let portalUrl: String
        }

        let response: PortalResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: true
        )

        guard let portalURL = URL(string: response.portalUrl) else {
            print("❌ [BackendAPI] Invalid portal URL: \(response.portalUrl)")
            throw BackendAPIError.invalidURL
        }

        print("✅ [BackendAPI] Portal session created: \(portalURL)")
        return portalURL
    }

    // MARK: - Receipt Management Endpoints

    /// Check if user can add a new receipt (premium OR under weekly limit)
    /// - Returns: Tuple of (canAdd, receiptUsage)
    func canAddReceipt() async throws -> (canAdd: Bool, usage: ReceiptUsage) {
        print("🔍 [BackendAPI] Checking receipt limit...")

        let endpoint = "/api/receipts/can-add-receipt"
        let canAddResponse: CanAddReceiptResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: true
        )

        guard let usage = canAddResponse.toReceiptUsage() else {
            print("❌ [BackendAPI] Failed to decode receipt usage")
            throw BackendAPIError.decodingFailed
        }

        print("✅ [BackendAPI] Can add receipt: \(canAddResponse.canAdd), Usage: \(usage.receiptsThisWeek)/5")
        return (canAddResponse.canAdd, usage)
    }

    /// Increment receipt count after successful receipt save
    /// - Returns: Updated ReceiptUsage
    func incrementReceiptCount() async throws -> ReceiptUsage {
        print("📈 [BackendAPI] Incrementing receipt count...")

        let endpoint = "/api/receipts/increment-count"
        let incrementResponse: IncrementCountResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: [:],
            requiresAuth: true
        )

        guard let usage = incrementResponse.toReceiptUsage() else {
            print("❌ [BackendAPI] Failed to decode receipt usage")
            throw BackendAPIError.decodingFailed
        }

        print("✅ [BackendAPI] Receipt count incremented: \(usage.receiptsThisWeek)/5")
        return usage
    }

    /// Get detailed receipt usage statistics
    /// - Returns: ReceiptUsage with full stats
    func getReceiptUsage() async throws -> ReceiptUsage {
        print("📊 [BackendAPI] Fetching receipt usage stats...")

        let endpoint = "/api/receipts/usage-stats"
        let statsResponse: UsageStatsResponse = try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            body: nil,
            requiresAuth: true
        )

        guard let usage = statsResponse.toReceiptUsage() else {
            print("❌ [BackendAPI] Failed to decode receipt usage")
            throw BackendAPIError.decodingFailed
        }

        print("✅ [BackendAPI] Receipt usage stats: \(usage.receiptsThisWeek)/5 this week")
        return usage
    }
}

// MARK: - Streaming Progress Models

enum AIStreamingStage: String, CaseIterable {
    case initializing = "initializing"
    case analyzing = "analyzing"
    case extracting = "extracting"
    case processing = "processing"
    case validating = "validating"
    case complete = "complete"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .initializing: return "Initializing"
        case .analyzing: return "Analyzing Receipt"
        case .extracting: return "Extracting Data"
        case .processing: return "Processing Information"
        case .validating: return "Validating Results"
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }
    
    var systemImage: String {
        switch self {
        case .initializing: return "gear"
        case .analyzing: return "magnifyingglass"
        case .extracting: return "doc.text.viewfinder"
        case .processing: return "brain.head.profile"
        case .validating: return "checkmark.shield"
        case .complete: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .initializing: return .blue
        case .analyzing: return .purple
        case .extracting: return .orange
        case .processing: return .green
        case .validating: return .blue
        case .complete: return .green
        case .error: return .red
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .initializing: return 0.5
        case .analyzing: return 2.0
        case .extracting: return 3.0
        case .processing: return 2.5
        case .validating: return 1.0
        case .complete: return 0.0
        case .error: return 0.0
        }
    }
}

struct AIStreamingProgress {
    let stage: AIStreamingStage
    let progress: Double // 0.0 to 1.0
    let message: String
    let partialText: String
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var isComplete: Bool {
        return stage == .complete || stage == .error
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
    let response: AIContentData
}

struct AIContentData: Codable {
    let text: String
}

struct ReceiptValidationResponse: Codable {
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
    let discountDescription: String?
}

struct ImageUploadResponse: Codable {
    let url: String
    let provider: String
}

struct MultipleImageUploadResponse: Codable {
    let images: [MultipleImageUploadResult]
}

struct MultipleImageUploadResult: Codable {
    let url: String
    let provider: String
    let success: Bool
    let error: String?
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
