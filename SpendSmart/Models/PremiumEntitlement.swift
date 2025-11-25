//
//  PremiumEntitlement.swift
//  SpendSmart
//
//  Premium subscription status and receipt usage tracking models
//

import Foundation

/// Premium subscription entitlement information
/// Represents the user's Stripe subscription status
struct PremiumEntitlement: Codable, Equatable {
    let isPremium: Bool
    let stripeCustomerId: String?
    let subscriptionId: String?
    let subscriptionStatus: String?
    let currentPeriodEnd: Date?
    let planType: String?  // "monthly" | "annual"

    /// Whether the subscription is currently active
    var isActive: Bool {
        guard isPremium else { return false }
        return ["active", "trialing"].contains(subscriptionStatus)
    }

    /// Days remaining until subscription renewal or expiration
    var daysUntilRenewal: Int? {
        guard let end = currentPeriodEnd else { return nil }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: end)
        return components.day
    }

    /// Display-friendly status string
    var displayStatus: String {
        guard isPremium else { return "Free" }

        switch subscriptionStatus {
        case "active":
            return "Active"
        case "trialing":
            return "Trial"
        case "past_due":
            return "Payment Failed"
        case "canceled":
            return "Expires Soon"
        case "incomplete":
            return "Pending"
        default:
            return "Premium"
        }
    }

    /// Display-friendly plan name
    var displayPlanName: String {
        guard isPremium, let planType = planType else { return "Free" }

        switch planType {
        case "monthly":
            return "Premium Monthly"
        case "annual":
            return "Premium Annual"
        default:
            return "Premium"
        }
    }

    /// Renewal date formatted for display
    var renewalDateFormatted: String? {
        guard let end = currentPeriodEnd else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: end)
    }

    /// Default free tier entitlement
    static let free = PremiumEntitlement(
        isPremium: false,
        stripeCustomerId: nil,
        subscriptionId: nil,
        subscriptionStatus: nil,
        currentPeriodEnd: nil,
        planType: nil
    )
}

/// Receipt usage tracking for free tier limits
/// Tracks weekly receipt count and reset information
struct ReceiptUsage: Codable, Equatable {
    let receiptsThisWeek: Int
    let weekResetDate: Date
    let totalAllTime: Int?

    /// Number of receipts remaining before hitting limit (free tier only)
    var remainingReceipts: Int {
        max(0, 5 - receiptsThisWeek)
    }

    /// Whether the weekly limit has been reached
    var isLimitReached: Bool {
        receiptsThisWeek >= 5
    }

    /// Progress percentage towards limit (0.0 to 1.0)
    var progressPercentage: Double {
        min(1.0, Double(receiptsThisWeek) / 5.0)
    }

    /// Days until weekly reset
    var daysUntilReset: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: weekResetDate)
        return max(0, components.day ?? 0)
    }

    /// Formatted reset date for display
    var resetDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: weekResetDate)
    }

    /// Relative time until reset (e.g., "in 3 days")
    var resetTimeRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: weekResetDate, relativeTo: Date())
    }

    /// Usage status message for display
    var statusMessage: String {
        if isLimitReached {
            return "Limit reached • Resets \(resetTimeRelative)"
        } else {
            return "\(receiptsThisWeek)/5 receipts • Resets \(resetTimeRelative)"
        }
    }

    /// Color indicator based on usage
    var statusColor: String {
        switch receiptsThisWeek {
        case 0...2:
            return "green"
        case 3...4:
            return "orange"
        default:
            return "red"
        }
    }
}

/// Response model for backend can-add-receipt endpoint
struct CanAddReceiptResponse: Codable {
    let canAdd: Bool
    let receiptsUsed: Int
    let limit: Int?  // nil for premium (unlimited)
    let resetDate: String
    let isPremium: Bool

    /// Convert to ReceiptUsage model
    func toReceiptUsage() -> ReceiptUsage? {
        guard let date = ISO8601DateFormatter().date(from: resetDate) else {
            return nil
        }

        return ReceiptUsage(
            receiptsThisWeek: receiptsUsed,
            weekResetDate: date,
            totalAllTime: nil
        )
    }
}

/// Response model for backend increment-count endpoint
struct IncrementCountResponse: Codable {
    let receiptsThisWeek: Int
    let weekResetDate: String
    let isPremium: Bool

    /// Convert to ReceiptUsage model
    func toReceiptUsage() -> ReceiptUsage? {
        guard let date = ISO8601DateFormatter().date(from: weekResetDate) else {
            return nil
        }

        return ReceiptUsage(
            receiptsThisWeek: receiptsThisWeek,
            weekResetDate: date,
            totalAllTime: nil
        )
    }
}

/// Response model for backend usage-stats endpoint
struct UsageStatsResponse: Codable {
    let receiptsThisWeek: Int
    let weekResetDate: String
    let totalAllTime: Int?
    let isPremium: Bool
    let limit: Int?
    let remainingThisWeek: Int?

    /// Convert to ReceiptUsage model
    func toReceiptUsage() -> ReceiptUsage? {
        guard let date = ISO8601DateFormatter().date(from: weekResetDate) else {
            return nil
        }

        return ReceiptUsage(
            receiptsThisWeek: receiptsThisWeek,
            weekResetDate: date,
            totalAllTime: totalAllTime
        )
    }
}

/// Error type for receipt limit violations
enum ReceiptLimitError: LocalizedError {
    case limitReached(usage: ReceiptUsage)
    case networkError(String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .limitReached(let usage):
            return "You've reached your weekly limit of 5 receipts. \(usage.remainingReceipts) remaining. Resets \(usage.resetTimeRelative). Upgrade to Premium for unlimited receipts."
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknownError:
            return "An unknown error occurred while checking receipt limits."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .limitReached:
            return "Upgrade to Premium for unlimited receipt processing and cloud sync."
        case .networkError:
            return "Please check your internet connection and try again."
        case .unknownError:
            return "Please try again later."
        }
    }
}
