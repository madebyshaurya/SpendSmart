import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Manager

/// Manages all local notifications for SpendSmart including budget alerts and weekly summaries
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let center = UNUserNotificationCenter.current()
    
    // Notification identifiers
    private enum NotificationID {
        static let weeklySummary = "weekly.summary"
        static let dailyReminder = "daily.reminder"
    }
    
    private init() {
        Task { await checkAuthorizationStatus() }
    }
    
    // MARK: - Authorization
    
    /// Request notification permissions from the user
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run { isAuthorized = granted }
            
            if granted {
                print("✅ [Notifications] Authorization granted")
                await scheduleDefaultNotifications()
            } else {
                print("⚠️ [Notifications] Authorization denied")
            }
            
            return granted
        } catch {
            print("❌ [Notifications] Authorization error: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    /// Open app notification settings
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Weekly Summary
    
    /// Schedule weekly summary notifications (every Sunday at 6 PM)
    func scheduleWeeklySummary() {
        guard isAuthorized else { return }
        
        // Remove existing weekly summary
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.weeklySummary])
        
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Spending Summary"
        content.body = "Tap to see how much you spent this week and where your money went."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        content.userInfo = ["type": "weekly_summary"]
        
        // Every Sunday at 6 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationID.weeklySummary, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ [Notifications] Weekly summary error: \(error)")
            } else {
                print("✅ [Notifications] Weekly summary scheduled")
            }
        }
    }
    
    /// Send an immediate weekly summary with actual data
    func sendWeeklySummaryNow(totalSpent: Double, receiptCount: Int, topCategory: String?) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Spending Summary"
        
        var body = "This week you spent $\(String(format: "%.2f", totalSpent)) across \(receiptCount) receipt\(receiptCount == 1 ? "" : "s")."
        if let category = topCategory {
            body += " Top category: \(category)."
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationID.weeklySummary).immediate", content: content, trigger: trigger)
        
        center.add(request)
    }
    
    // MARK: - Daily Reminder
    
    /// Schedule a daily reminder to scan receipts (configurable time)
    func scheduleDailyReminder(at hour: Int = 20, minute: Int = 0) {
        guard isAuthorized else { return }
        
        // Remove existing daily reminder
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyReminder])
        
        let content = UNMutableNotificationContent()
        content.title = "Got any receipts today?"
        content.body = "Don't forget to scan your receipts to keep your spending on track."
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"
        content.userInfo = ["type": "daily_reminder"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationID.dailyReminder, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ [Notifications] Daily reminder error: \(error)")
            } else {
                print("✅ [Notifications] Daily reminder scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }
    
    /// Cancel daily reminder
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyReminder])
        print("✅ [Notifications] Daily reminder cancelled")
    }
    
    // MARK: - Helpers
    
    /// Schedule default notifications after authorization
    private func scheduleDefaultNotifications() async {
        scheduleWeeklySummary()
    }
    
    /// Get all pending notifications
    func fetchPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        await MainActor.run {
            pendingNotifications = requests
        }
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        print("✅ [Notifications] All notifications cancelled")
    }
    
    /// Cancel specific notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Set badge count
    func setBadgeCount(_ count: Int) {
        Task {
            do {
                try await center.setBadgeCount(count)
            } catch {
                print("❌ [Notifications] Badge count error: \(error)")
            }
        }
    }
    
    /// Clear badge
    func clearBadge() {
        setBadgeCount(0)
    }
}

// MARK: - Notification Settings View

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var haptics = HapticManager.shared
    
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("weeklySummaryEnabled") private var weeklySummaryEnabled = true
    
    var body: some View {
        List {
            // Authorization Section
            Section {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(notificationManager.isAuthorized ? Color.brandSuccess.opacity(0.15) : Color.brandWarning.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: notificationManager.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(notificationManager.isAuthorized ? Color.brandSuccess : Color.brandWarning)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                            .font(.manrope(size: 15, weight: .semibold))
                            .foregroundStyle(Color.brandTextPrimary)
                        
                        Text(notificationManager.isAuthorized ? "You'll receive alerts and summaries" : "Enable to get spending alerts")
                            .font(.manrope(size: 12))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                    
                    Spacer()
                    
                    if !notificationManager.isAuthorized {
                        Button {
                            haptics.buttonPress()
                            Task {
                                _ = await notificationManager.requestAuthorization()
                            }
                        } label: {
                            Text("Enable")
                                .font(.manrope(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.brandVibrantBlue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Settings Section (only if authorized)
            if notificationManager.isAuthorized {
                Section {
                    Toggle(isOn: $weeklySummaryEnabled) {
                        SettingRow(
                            icon: "calendar.badge.clock",
                            iconColor: .brandVibrantBlue,
                            title: "Weekly Summary",
                            subtitle: "Receive spending summary on Sundays"
                        )
                    }
                    .tint(.brandVibrantBlue)
                    .onChange(of: weeklySummaryEnabled) { _, enabled in
                        if enabled {
                            notificationManager.scheduleWeeklySummary()
                        } else {
                            notificationManager.cancelNotification(identifier: "weekly.summary")
                        }
                    }
                    
                    Toggle(isOn: $dailyReminderEnabled) {
                        SettingRow(
                            icon: "bell.badge.fill",
                            iconColor: .brandWarning,
                            title: "Daily Reminder",
                            subtitle: "Remind to scan receipts daily"
                        )
                    }
                    .tint(.brandVibrantBlue)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        if enabled {
                            notificationManager.scheduleDailyReminder(at: dailyReminderHour)
                        } else {
                            notificationManager.cancelDailyReminder()
                        }
                    }
                    
                    if dailyReminderEnabled {
                        HStack {
                            Text("Reminder Time")
                                .font(.manrope(size: 14))
                                .foregroundStyle(Color.brandTextSecondary)
                            
                            Spacer()
                            
                            Picker("Hour", selection: $dailyReminderHour) {
                                ForEach(6..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: dailyReminderHour) { _, hour in
                                if dailyReminderEnabled {
                                    notificationManager.scheduleDailyReminder(at: hour)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Notification Types")
                }
                
                Section {
                    Button {
                        haptics.buttonPress()
                        notificationManager.openSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                            Text("Open System Settings")
                                .font(.manrope(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.brandVibrantBlue)
                    }
                } footer: {
                    Text("Manage notification permissions in system settings")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Setting Row

private struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(subtitle)
                    .font(.manrope(size: 11))
                    .foregroundStyle(Color.brandTextTertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
