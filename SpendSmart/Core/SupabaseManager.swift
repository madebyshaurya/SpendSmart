import Auth
import Combine
import Foundation
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    @Published var currentUser: User? = nil
    @Published var session: Auth.Session? = nil
    @Published var profile: Profile? = nil

    private init() {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL: \(supabaseURL). Check APIKeys.swift configuration.")
        }
        let options = SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey,
            options: options
        )
        Task { await listenForAuthChanges() }
    }

    @MainActor
    private func listenForAuthChanges() async {
        for await state in client.auth.authStateChanges {
            self.session = state.session
            self.currentUser = state.session?.user
            if state.session != nil {
                await refreshProfile()
            } else {
                await MainActor.run { self.profile = nil }
            }
        }
    }

    func signInWithApple(idToken: String) async throws {
        let credentials = Auth.OpenIDConnectCredentials(provider: .apple, idToken: idToken)
        try await client.auth.signInWithIdToken(credentials: credentials)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run { self.profile = nil }
    }
    
    func getAuthToken() async -> String? {
        session?.accessToken
    }

    func refreshProfile() async {
        guard let userId = session?.user.id else {
            await MainActor.run { self.profile = nil }
            return
        }

        do {
            let profiles: [Profile] = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            await MainActor.run { self.profile = profiles.first }
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    func upsertProfileName(_ name: String) async throws -> Profile {
        guard let userId = session?.user.id else {
            throw NSError(
                domain: "SupabaseManager", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NSError(
                domain: "SupabaseManager", code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Display name cannot be empty"])
        }

        let payload = Profile(id: userId, full_name: trimmedName, created_at: nil, updated_at: nil)
        let updatedProfile: Profile = try await client.from("profiles")
            .upsert(payload, onConflict: "id")
            .select()
            .single()
            .execute()
            .value

        await MainActor.run { self.profile = updatedProfile }
        return updatedProfile
    }

    func ensureProfileNameExists(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let existingName = await MainActor.run { self.profile?.full_name }
            if let currentName = existingName,
                !currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                let normalized = currentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let placeholders = ["spendsmart user", "ben smart user"]
                if !placeholders.contains(normalized) {
                    return
                }
            }
            _ = try await upsertProfileName(trimmed)
        } catch {
            print("Failed to persist initial profile name: \(error)")
        }
    }

    func fetchTotalSpent(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let userId = session?.user.id else { return 0.0 }

        struct AmountResult: Decodable {
            let total_amount: Double
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let results: [AmountResult] = try await client.from("receipts")
            .select("total_amount")
            .eq("user_id", value: userId)
            .gte("purchase_date", value: formatter.string(from: startDate))
            .lte("purchase_date", value: formatter.string(from: endDate))
            .execute()
            .value

        return results.reduce(0) { $0 + $1.total_amount }
    }

    func fetchReceipts(page: Int = 1, limit: Int = 50) async throws -> [Receipt] {
        guard let userId = session?.user.id else { return [] }
        let offset = (page - 1) * limit
        return try await client.from("receipts")
            .select()
            .eq("user_id", value: userId)
            .order("purchase_date", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func createReceipt(_ receipt: Receipt) async throws -> Receipt {
        guard let userId = session?.user.id else {
            throw NSError(
                domain: "SupabaseManager", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        var r = receipt
        r.user_id = userId
        return try await client.from("receipts").insert(r).select().single().execute().value
    }

    func updateReceipt(_ receipt: Receipt) async throws -> Receipt {
        try await client.from("receipts")
            .update(receipt)
            .eq("id", value: receipt.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteReceipt(id: String) async throws {
        try await client.from("receipts").delete().eq("id", value: id).execute()
    }

    func deleteAccount() async throws {
        try await BackendAPIService.shared.deleteAccount()
    }
    
    // MARK: - User Usage Tracking
    
    /// Fetches the user's usage record
    func fetchUserUsage() async throws -> UserUsage? {
        guard let userId = session?.user.id else { return nil }
        
        let results: [UserUsage] = try await client.from("user_usage")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return results.first
    }
    
    /// Creates or updates user usage record
    func upsertUserUsage(_ usage: UserUsage) async throws -> UserUsage {
        guard let userId = session?.user.id else {
            throw NSError(
                domain: "SupabaseManager", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        var usageToSave = usage
        usageToSave.user_id = userId
        
        return try await client.from("user_usage")
            .upsert(usageToSave, onConflict: "user_id")
            .select()
            .single()
            .execute()
            .value
    }
    
    /// Increments the scan count for the user (for analytics)
    func incrementScanCount() async throws {
        guard let userId = session?.user.id else { return }
        
        struct Params: Encodable {
            let user_id_input: UUID
        }
        
        try await client
            .rpc("increment_scan_usage", params: Params(user_id_input: userId))
            .execute()
        
        // Refresh local cache
        _ = try? await fetchUserUsage()
    }
    
    func saveOnboardingInsights(intent: String, referral: String) async {
        guard let userId = session?.user.id else { return }
        
        struct InsightPayload: Encodable {
            let user_id: UUID
            let usage_intent: String
            let referral_source: String
        }
        
        do {
            try await client.from("onboarding_insights")
                .insert(InsightPayload(user_id: userId, usage_intent: intent, referral_source: referral))
                .execute()
        } catch {
            print("Failed to save insights: \(error)")
        }
    }
    
    /// Updates the user's subscription status in Supabase (Deprecated: Server-side webhook is now authoritative)
    func updateSubscriptionStatus(isSubscribed: Bool, tier: String, expiresAt: Date?) async throws {
        // No-op: Direct client updates are blocked by RLS for security.
        // The RevenueCat webhook handles this on the backend.
        print("🔒 [Supabase] Client-side subscription update skipped (Server authoritative)")
    }
}

// MARK: - User Usage Model

struct UserUsage: Codable {
    var id: UUID?
    var user_id: UUID?
    var total_scans: Int
    var scans_this_month: Int
    var last_scan_at: Date?
    var first_scan_at: Date?
    var free_scan_used: Bool
    var is_subscribed: Bool
    var subscription_tier: String?
    var subscription_expires_at: Date?
    var revenuecat_customer_id: String?
    var current_month_start: Date?
    var is_legacy_user: Bool
    var has_cloud_access: Bool
    var created_at: Date?
    var updated_at: Date?
    
    init(
        id: UUID? = nil,
        user_id: UUID? = nil,
        total_scans: Int = 0,
        scans_this_month: Int = 0,
        last_scan_at: Date? = nil,
        first_scan_at: Date? = nil,
        free_scan_used: Bool = false,
        is_subscribed: Bool = false,
        subscription_tier: String? = "free",
        subscription_expires_at: Date? = nil,
        revenuecat_customer_id: String? = nil,
        current_month_start: Date? = nil,
        is_legacy_user: Bool = false,
        has_cloud_access: Bool = false,
        created_at: Date? = nil,
        updated_at: Date? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.total_scans = total_scans
        self.scans_this_month = scans_this_month
        self.last_scan_at = last_scan_at
        self.first_scan_at = first_scan_at
        self.free_scan_used = free_scan_used
        self.is_subscribed = is_subscribed
        self.subscription_tier = subscription_tier
        self.subscription_expires_at = subscription_expires_at
        self.revenuecat_customer_id = revenuecat_customer_id
        self.current_month_start = current_month_start
        self.is_legacy_user = is_legacy_user
        self.has_cloud_access = has_cloud_access
        self.created_at = created_at
        self.updated_at = updated_at
    }
}
