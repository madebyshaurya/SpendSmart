//
//  SupabaseManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//  Updated for Backend API Integration on 2025-07-29.
//

import Foundation
import Supabase
import Auth

/// Manager for handling authentication and data operations
class SupabaseManager {
    static let shared = SupabaseManager()

    // Direct Supabase client for anon key operations
    private let supabaseClient: SupabaseClient

    // Backend API service for operations requiring service role key
    private let backendAPI = BackendAPIService.shared

    private init() {
        // Initialize Supabase client with anon key
        self.supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://jktpejlmzgeaulthsckw.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImprdHBlamxtemdlYXVsdGhzY2t3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4Mjg3MTksImV4cCI6MjA1NzQwNDcxOX0.iQFlaVEm16FjWSUpLGkj4XYO-eztUAP3EPNM5I7Hp90"
        )
    }

    // MARK: - Authentication Methods (using anon key)

    /// Sign in with Apple ID token
    func signInWithApple(idToken: String) async throws -> CustomAuthResponse {
        print("🍎 [SupabaseManager] Starting Apple Sign In with ID token")
        print("🔐 [SupabaseManager] ID Token length: \(idToken.count) characters")
        
        let credentials = Auth.OpenIDConnectCredentials(provider: .apple, idToken: idToken)
        print("🔐 [SupabaseManager] Created OpenID credentials for Apple provider")
        
        do {
            print("📡 [SupabaseManager] Sending sign-in request to Supabase...")
            let session = try await supabaseClient.auth.signInWithIdToken(credentials: credentials)
            print("✅ [SupabaseManager] Supabase sign-in successful!")
            
            let user = session.user
            print("👤 [SupabaseManager] User ID: \(user.id.uuidString)")
            print("📧 [SupabaseManager] User Email: \(user.email ?? "nil")")
            print("📅 [SupabaseManager] User Created: \(user.createdAt.description)")
            print("🔐 [SupabaseManager] Access Token: \(session.accessToken.prefix(20))...")
            print("⏰ [SupabaseManager] Token Expires: \(session.expiresAt.description)")

            let response = CustomAuthResponse(
                data: CustomAuthData(
                    user: CustomUser(
                        id: user.id.uuidString,
                        email: user.email,
                        created_at: user.createdAt.description,
                        last_sign_in_at: user.lastSignInAt?.description
                    ),
                    session: CustomSession(
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        expiresAt: session.expiresAt.description
                    )
                )
            )
            
            print("🎉 [SupabaseManager] Apple Sign In completed successfully")
            return response
        } catch {
            print("❌ [SupabaseManager] Apple Sign In failed: \(error.localizedDescription)")
            print("❌ [SupabaseManager] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [SupabaseManager] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [SupabaseManager] Error userInfo: \(nsError.userInfo)")
            }
            throw error
        }
    }

    /// Create a guest user account
    func createGuestAccount() async throws -> CustomAuthResponse {
        let randomNum = Int.random(in: 10000...99999)
        let guestEmail = "guest\(randomNum)@spend-smart.co"
        let guestPassword = "Guest123!_\(randomNum)"

        let response = try await supabaseClient.auth.signUp(
            email: guestEmail,
            password: guestPassword,
            data: ["is_guest": true, "created_via": "guest_mode"]
        )

        guard let session = response.session else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session returned from sign up"])
        }

        return CustomAuthResponse(
            data: CustomAuthData(
                user: CustomUser(
                    id: session.user.id.uuidString,
                    email: session.user.email,
                    created_at: session.user.createdAt.description,
                    last_sign_in_at: session.user.lastSignInAt?.description
                ),
                session: CustomSession(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken,
                    expiresAt: session.expiresAt.description
                ),
                credentials: Credentials(
                    email: guestEmail,
                    password: guestPassword
                )
            )
        )
    }

    /// Sign out the current user
    func signOut() async throws {
        try await supabaseClient.auth.signOut()
    }

    /// Get current user
    func getCurrentUser() async -> CustomUser? {
        print("👤 [SupabaseManager] Getting current user...")
        do {
            let session = try await supabaseClient.auth.session
            let user = session.user
            let customUser = CustomUser(
                id: user.id.uuidString,
                email: user.email,
                created_at: user.createdAt.description,
                last_sign_in_at: user.lastSignInAt?.description
            )
            print("✅ [SupabaseManager] Current user found - ID: \(customUser.id), Email: \(customUser.email ?? "nil")")
            return customUser
        } catch {
            print("❌ [SupabaseManager] Failed to get current user: \(error.localizedDescription)")
            return nil
        }
    }

    /// Synchronous current user getter for backward compatibility
    var currentUser: CustomUser? {
        // This is a simplified version that may not work in all cases
        // For proper async access, use getCurrentUser() instead
        return nil
    }

    // MARK: - Receipt Data Methods (using anon key)

    /// Fetch all receipts for the current user
    func fetchReceipts(page: Int = 1, limit: Int = 50) async throws -> [Receipt] {
        print("🔍 [SupabaseManager] Starting fetchReceipts - page: \(page), limit: \(limit)")
        let offset = (page - 1) * limit
        
        let currentUser = await getCurrentUser()
        let userId = currentUser?.id ?? ""
        print("👤 [SupabaseManager] Current user ID: \(userId)")
        
        if userId.isEmpty {
            print("❌ [SupabaseManager] No user ID found, user not authenticated")
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("📡 [SupabaseManager] Making Supabase query - table: receipts, user_id: \(userId), offset: \(offset), limit: \(limit)")
        
        do {
            let response: [Receipt] = try await supabaseClient
                .from("receipts")
                .select()
                .eq("user_id", value: userId)
                .order("purchase_date", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            print("✅ [SupabaseManager] Successfully fetched \(response.count) receipts")
            
            // Log details about each receipt for debugging
            for (index, receipt) in response.enumerated() {
                print("📋 [SupabaseManager] Receipt \(index + 1): ID=\(receipt.id), Store=\(receipt.store_name), Amount=\(receipt.total_amount), Items=\(receipt.items.count)")
            }
            
            return response
        } catch {
            print("❌ [SupabaseManager] Supabase query failed: \(error)")
            print("❌ [SupabaseManager] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [SupabaseManager] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [SupabaseManager] Error userInfo: \(nsError.userInfo)")
            }
            throw error
        }
    }

    /// Create a new receipt
    func createReceipt(_ receipt: Receipt) async throws -> Receipt {
        let response: Receipt = try await supabaseClient
            .from("receipts")
            .insert(receipt)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    /// Update an existing receipt
    func updateReceipt(_ receipt: Receipt) async throws -> Receipt {
        let response: Receipt = try await supabaseClient
            .from("receipts")
            .update(receipt)
            .eq("id", value: receipt.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    /// Delete a receipt by ID
    func deleteReceipt(id: String) async throws {
        try await supabaseClient
            .from("receipts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Delete multiple receipts by IDs
    func deleteReceipts(ids: [String]) async throws {
        for id in ids {
            try await deleteReceipt(id: id)
        }
    }

    // MARK: - Service Role Operations (using backend)

    /// Delete the current user's account (requires service role)
    func deleteAccount() async throws {
        try await backendAPI.deleteAccount()
    }

    /// Delete a guest account by user ID (requires service role)
    func deleteGuestAccount(userId: String) async throws {
        try await backendAPI.deleteGuestAccount(userId: userId)
    }

    // MARK: - Authentication State

    /// Check if the user is currently authenticated
    func isAuthenticated() async -> Bool {
        do {
            let _ = try await supabaseClient.auth.session
            return true
        } catch {
            return false
        }
    }

    /// Get the current authentication token
    func getAuthToken() async -> String? {
        do {
            let session = try await supabaseClient.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }

    /// Set the authentication token manually
    func setAuthToken(_ token: String?) {
        // This would need to be handled differently with the Supabase client
        // For now, we'll rely on the client's built-in session management
    }

    // MARK: - Legacy Auth Support

    /// Legacy auth property for backward compatibility
    var auth: AuthManager {
        return AuthManager()
    }
}

// MARK: - Response Models

struct CustomAuthResponse {
    let data: CustomAuthData
}

struct CustomAuthData {
    let user: CustomUser?
    let session: CustomSession?
    let credentials: Credentials?
    let isNewUser: Bool?

    init(user: CustomUser? = nil, session: CustomSession? = nil, credentials: Credentials? = nil, isNewUser: Bool? = nil) {
        self.user = user
        self.session = session
        self.credentials = credentials
        self.isNewUser = isNewUser
    }
}

struct CustomUser {
    let id: String
    let email: String?
    let created_at: String?
    let last_sign_in_at: String?
}

struct CustomSession {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: String?
}

struct Credentials {
    let email: String
    let password: String
}

// MARK: - Legacy User Model

/// Legacy user model for backward compatibility
struct LegacyUser {
    let id: UUID
    let email: String?

    init(id: UUID, email: String? = nil) {
        self.id = id
        self.email = email
    }
}

// MARK: - Legacy Authentication Types

/// Legacy authentication session for backward compatibility
struct AuthSession {
    let user: LegacyUser
    let accessToken: String
}

/// Legacy OpenID Connect credentials for backward compatibility
struct OpenIDConnectCredentials {
    let provider: AuthProvider
    let idToken: String

    init(provider: AuthProvider, idToken: String) {
        self.provider = provider
        self.idToken = idToken
    }
}

/// Legacy authentication provider enum
enum AuthProvider {
    case apple
}

// MARK: - Legacy Support

/// Legacy global instance for backward compatibility
let supabase = SupabaseManager.shared

// MARK: - Legacy Auth Manager

/// Legacy auth manager for backward compatibility
class AuthManager {
    /// Legacy currentUser property
    var currentUser: LegacyUser? {
        guard let user = SupabaseManager.shared.currentUser else { return nil }
        return LegacyUser(id: UUID(uuidString: user.id) ?? UUID(), email: user.email)
    }

    /// Legacy signInWithIdToken method for backward compatibility
    func signInWithIdToken(credentials: OpenIDConnectCredentials) async throws -> AuthSession {
        let response = try await SupabaseManager.shared.signInWithApple(idToken: credentials.idToken)
        
        return AuthSession(
            user: LegacyUser(id: UUID(uuidString: response.data.user?.id ?? "") ?? UUID(), email: response.data.user?.email),
            accessToken: response.data.session?.accessToken ?? ""
        )
    }

    /// Legacy signUp method for backward compatibility
    func signUp(email: String, password: String, data: [String: Any]? = nil) async throws -> AuthSession {
        let response = try await SupabaseManager.shared.createGuestAccount()

        return AuthSession(
            user: LegacyUser(id: UUID(uuidString: response.data.user?.id ?? "") ?? UUID(), email: response.data.user?.email),
            accessToken: response.data.session?.accessToken ?? ""
        )
    }

    /// Legacy signOut method for backward compatibility
    func signOut() async throws {
        try await SupabaseManager.shared.signOut()
    }
}

