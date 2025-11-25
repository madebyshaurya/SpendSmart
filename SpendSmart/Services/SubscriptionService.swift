//
//  SubscriptionService.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-08-13.
//

import Foundation
import UserNotifications
import SwiftUI

final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var subscriptions: [Subscription] = []

    private let storageKey = "subscriptions_store"

    private init() {
        load()
    }

    // MARK: - CRUD Local
    func load() {
        print("🔄 [SubscriptionService] Loading subscriptions from UserDefaults")
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📭 [SubscriptionService] No stored subscription data found, initializing empty array")
            self.subscriptions = []
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.subscriptions = try decoder.decode([Subscription].self, from: data)
            print("✅ [SubscriptionService] Successfully loaded \(subscriptions.count) subscriptions")
        } catch {
            print("❌ [SubscriptionService] Failed to load subscriptions: \(error)")
            self.subscriptions = []
        }
    }

    func save() {
        print("💾 [SubscriptionService] Saving \(subscriptions.count) subscriptions to UserDefaults")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(subscriptions)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("✅ [SubscriptionService] Successfully saved subscriptions")
        } catch {
            print("❌ [SubscriptionService] Failed to save subscriptions: \(error)")
        }
    }

    func upsert(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            print("🔄 [SubscriptionService] Updating existing subscription: \(subscription.service_name)")
            subscriptions[index] = subscription
        } else {
            print("➕ [SubscriptionService] Adding new subscription: \(subscription.service_name)")
            subscriptions.append(subscription)
        }
        save()
        scheduleNotifications(for: subscription)
        print("🔔 [SubscriptionService] Scheduled notifications for: \(subscription.service_name)")
    }

    func delete(id: UUID) {
        if let sub = subscriptions.first(where: { $0.id == id }) {
            print("🗑️ [SubscriptionService] Deleting subscription: \(sub.service_name)")
            cancelNotifications(for: sub)
        } else {
            print("⚠️ [SubscriptionService] Attempted to delete non-existent subscription with ID: \(id)")
        }
        subscriptions.removeAll { $0.id == id }
        save()
        print("✅ [SubscriptionService] Successfully deleted subscription")
    }

    func activeSubscriptions() -> [Subscription] {
        return subscriptions.filter { $0.is_active }
    }

    @MainActor
    func overwrite(with subs: [Subscription]) {
        self.subscriptions = subs
        save()
    }

    // MARK: - Totals
    func monthlyCost(inPreferredCurrency preferredCurrency: String, converter: (Double, String, String) -> Double) -> Double {
        var total = 0.0
        for s in subscriptions where s.is_active {
            let monthlyEquivalent = Self.proratedMonthlyAmount(for: s)
            total += converter(monthlyEquivalent, s.currency, preferredCurrency)
        }
        return total
    }
    
    func actualChargedMonthlyCost(inPreferredCurrency preferredCurrency: String, converter: (Double, String, String) -> Double) -> Double {
        var total = 0.0
        let calendar = Calendar.current
        let now = Date()
        
        for s in subscriptions where s.is_active {
            // Calculate how much has actually been charged this month
            let chargedAmount = Self.calculateChargedAmountThisMonth(for: s, currentDate: now, calendar: calendar)
            if chargedAmount > 0 {
                total += converter(chargedAmount, s.currency, preferredCurrency)
            }
        }
        return total
    }

    func yearlyCost(inPreferredCurrency preferredCurrency: String, converter: (Double, String, String) -> Double) -> Double {
        var total = 0.0
        for s in subscriptions where s.is_active {
            let yearlyEquivalent = Self.proratedYearlyAmount(for: s)
            total += converter(yearlyEquivalent, s.currency, preferredCurrency)
        }
        return total
    }

    static func proratedMonthlyAmount(for s: Subscription) -> Double {
        switch s.billing_cycle {
        case .weekly:
            return s.amount * (52.0 / 12.0)
        case .monthly:
            return s.amount
        case .quarterly:
            return s.amount / 3.0
        case .semiannual:
            return s.amount / 6.0
        case .annual:
            return s.amount / 12.0
        case .custom:
            let interval = max(1, s.interval_count ?? 1)
            return s.amount / Double(interval)
        }
    }

    static func proratedYearlyAmount(for s: Subscription) -> Double {
        switch s.billing_cycle {
        case .weekly:
            return s.amount * 52.0
        case .monthly:
            return s.amount * 12.0
        case .quarterly:
            return s.amount * 4.0
        case .semiannual:
            return s.amount * 2.0
        case .annual:
            return s.amount
        case .custom:
            let interval = max(1, s.interval_count ?? 1) // interval_count represents months between payments
            return s.amount * (12.0 / Double(interval)) // Convert to yearly: amount * (12 months / interval months)
        }
    }
    
    static func calculateChargedAmountThisMonth(for subscription: Subscription, currentDate: Date, calendar: Calendar) -> Double {
        let nextRenewal = subscription.next_renewal_date
        let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
        
        // If subscription is in trial and trial hasn't ended, no charges yet
        if subscription.is_trial, let trialEnd = subscription.trial_end_date, trialEnd > currentDate {
            return 0.0
        }
        
        // If next renewal is in the future (within this month or later), no charges have occurred yet
        if nextRenewal > currentDate {
            return 0.0
        }
        
        // Calculate how many billing periods have completed within this month
        var chargedAmount = 0.0
        var checkDate = nextRenewal
        
        // Work backwards to find charges that occurred this month
        while checkDate >= startOfMonth {
            // If this charge date is within this month, add the amount
            if checkDate >= startOfMonth && checkDate < endOfMonth {
                chargedAmount += subscription.amount
            }
            
            // Move to previous billing cycle
            checkDate = calculatePreviousBillingDate(from: checkDate, cycle: subscription.billing_cycle, intervalCount: subscription.interval_count, calendar: calendar)
            
            // Prevent infinite loops - only go back one year maximum
            if checkDate.timeIntervalSince(nextRenewal) < -365 * 24 * 60 * 60 {
                break
            }
        }
        
        return chargedAmount
    }
    
    private static func calculatePreviousBillingDate(from date: Date, cycle: Subscription.BillingCycle, intervalCount: Int?, calendar: Calendar) -> Date {
        switch cycle {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: -3, to: date) ?? date
        case .semiannual:
            return calendar.date(byAdding: .month, value: -6, to: date) ?? date
        case .annual:
            return calendar.date(byAdding: .year, value: -1, to: date) ?? date
        case .custom:
            let interval = max(1, intervalCount ?? 1)
            return calendar.date(byAdding: .month, value: -interval, to: date) ?? date
        }
    }

    // MARK: - Notifications
    func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 Notification permission: \(granted)")
        } catch {
            print("❌ Notification permission error: \(error)")
        }
    }

    func scheduleNotifications(for subscription: Subscription) {
        cancelNotifications(for: subscription)
        let center = UNUserNotificationCenter.current()

        // Renewal notification
        if subscription.is_active {
            let daysBefore = max(0, subscription.notify_before_renewal_days)
            let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: subscription.next_renewal_date)
            if let fireDate = fireDate, fireDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Renewal"
                content.body = "\(subscription.service_name) renews on \(Self.formatDate(subscription.next_renewal_date))."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Self.dateComponents(from: fireDate), repeats: false)
                let id = "sub-renewal-\(subscription.id.uuidString)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }

        // Trial end notification
        if subscription.is_trial, let trialEnd = subscription.trial_end_date {
            let daysBefore = max(0, subscription.notify_before_trial_end_days)
            let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: trialEnd)
            if let fireDate = fireDate, fireDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Trial Ending Soon"
                content.body = "Your \(subscription.service_name) trial ends on \(Self.formatDate(trialEnd))."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Self.dateComponents(from: fireDate), repeats: false)
                let id = "sub-trial-\(subscription.id.uuidString)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    func cancelNotifications(for subscription: Subscription) {
        let center = UNUserNotificationCenter.current()
        let ids = ["sub-renewal-\(subscription.id.uuidString)", "sub-trial-\(subscription.id.uuidString)"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func dateComponents(from date: Date) -> DateComponents {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return comps
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}


