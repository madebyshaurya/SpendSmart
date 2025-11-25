//
//  StripePaymentService.swift
//  SpendSmart
//
//  Handles Stripe payment flow for premium subscriptions
//

import Foundation
import UIKit

@MainActor
class StripePaymentService: ObservableObject {
    static let shared = StripePaymentService()

    @Published var isProcessing = false

    /// Subscription plan types
    enum PlanType: String, CaseIterable, Identifiable {
        case monthly = "monthly"
        case annual = "annual"

        var id: String { rawValue }

        /// Display price for the plan
        var displayPrice: String {
            switch self {
            case .monthly:
                return "$4.99/month"
            case .annual:
                return "$49.99/year"
            }
        }

        /// Monthly equivalent price
        var monthlyEquivalent: String {
            switch self {
            case .monthly:
                return "$4.99/mo"
            case .annual:
                return "$4.16/mo"
            }
        }

        /// Savings percentage for annual plan
        var savings: String? {
            switch self {
            case .monthly:
                return nil
            case .annual:
                return "Save 17%"
            }
        }

        /// Display name
        var displayName: String {
            rawValue.capitalized
        }

        /// Badge text for plan selector
        var badgeText: String? {
            switch self {
            case .monthly:
                return nil
            case .annual:
                return "Best Value"
            }
        }
    }

    private init() {}

    /// Purchase a subscription plan
    /// Opens Stripe checkout in Safari and waits for user to complete payment
    /// - Parameters:
    ///   - planType: The subscription plan to purchase
    ///   - completion: Called when user returns from Stripe (success or cancel)
    func purchaseSubscription(
        planType: PlanType,
        completion: @escaping (Result<Void, Error>) -> Void
    ) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Create Stripe checkout session via backend
            let checkoutURL = try await BackendAPIService.shared.createStripeCheckout(planType: planType.rawValue)

            print("💳 [Stripe] Opening checkout URL: \(checkoutURL)")

            // Open checkout URL in Safari
            await openURL(checkoutURL)

            // Note: We can't detect when user completes payment from Safari
            // User will be redirected back to app via URL scheme
            // Premium status will be synced when app resumes

            completion(.success(()))

        } catch {
            print("❌ [Stripe] Failed to create checkout: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    /// Open Stripe Customer Portal for subscription management
    /// Allows user to cancel, update payment method, see invoices
    func openCustomerPortal(completion: @escaping (Result<Void, Error>) -> Void) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Get portal URL from backend
            let portalURL = try await BackendAPIService.shared.getStripePortalURL()

            print("🔗 [Stripe] Opening customer portal: \(portalURL)")

            // Open portal in Safari
            await openURL(portalURL)

            completion(.success(()))

        } catch {
            print("❌ [Stripe] Failed to open portal: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    /// Restore purchases by syncing premium status from backend
    /// Useful for re-installs or when user switches devices
    /// - Parameter appState: AppState to update with synced status
    func restorePurchases(appState: AppState) async throws {
        isProcessing = true
        defer { isProcessing = false }

        print("🔄 [Stripe] Restoring purchases...")

        // Sync premium status from backend
        await appState.syncPremiumStatus()

        print("✅ [Stripe] Purchases restored - Premium: \(appState.isPremium)")

        if !appState.isPremium {
            throw StripeError.noPurchasesFound
        }
    }

    // MARK: - Helper Methods

    /// Open URL in Safari
    private func openURL(_ url: URL) async {
        await UIApplication.shared.open(url, options: [:])
    }
}

// MARK: - Error Types

enum StripeError: LocalizedError {
    case checkoutFailed(String)
    case portalFailed(String)
    case noPurchasesFound

    var errorDescription: String? {
        switch self {
        case .checkoutFailed(let message):
            return "Failed to open checkout: \(message)"
        case .portalFailed(let message):
            return "Failed to open customer portal: \(message)"
        case .noPurchasesFound:
            return "No premium subscription found. Please purchase a subscription first."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .checkoutFailed, .portalFailed:
            return "Please check your internet connection and try again."
        case .noPurchasesFound:
            return "You can purchase a subscription from the upgrade screen."
        }
    }
}
