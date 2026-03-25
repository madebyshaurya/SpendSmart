import Foundation
import UserNotifications

/// Computes spending insights locally on-device and schedules local notifications.
/// Plus-only feature — gated by SubscriptionManager.isPlus.
@MainActor
final class InsightsEngine: ObservableObject {
    static let shared = InsightsEngine()

    @Published var insights: [Insight] = []

    private let storageKey = "spendsmart_insights"
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Insight Model

    struct Insight: Identifiable, Codable {
        let id: UUID
        let type: InsightType
        let title: String
        let message: String
        let date: Date
        var isRead: Bool
        let category: String?
        let amount: Double?

        enum InsightType: String, Codable {
            case weeklySummary
            case spendingSpike
            case categoryMilestone
        }
    }

    // MARK: - Compute Insights

    /// Recompute insights from the given receipts. Call after saving a new receipt.
    func recompute(receipts: [Receipt]) {
        guard SubscriptionManager.shared.isPlus else { return }

        var newInsights: [Insight] = []

        // 1. Spending spike detection (this week vs average)
        if let spike = detectSpendingSpike(receipts: receipts) {
            newInsights.append(spike)
        }

        // 2. Category milestone detection
        newInsights.append(contentsOf: detectCategoryMilestones(receipts: receipts))

        // Merge with existing (avoid duplicates by type + date combo)
        let existingIds = Set(insights.map { "\($0.type.rawValue)-\(Calendar.current.startOfDay(for: $0.date))" })
        let filtered = newInsights.filter { insight in
            let key = "\(insight.type.rawValue)-\(Calendar.current.startOfDay(for: insight.date))"
            return !existingIds.contains(key)
        }

        insights.append(contentsOf: filtered)
        pruneOldInsights()
        save()

        // Schedule notifications for new insights
        for insight in filtered {
            scheduleNotification(for: insight)
        }

        // Reschedule weekly summary with latest data
        rescheduleWeeklySummary(receipts: receipts)
    }

    // MARK: - Spending Spike Detection

    private func detectSpendingSpike(receipts: [Receipt]) -> Insight? {
        let calendar = Calendar.current
        let now = Date()

        // This week's spending
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekTotal = receipts
            .filter { $0.purchase_date >= startOfWeek }
            .reduce(0) { $0 + $1.total_amount }

        // Average weekly spending (last 4 weeks, excluding this week)
        let fourWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -4, to: startOfWeek) ?? now
        let priorReceipts = receipts.filter { $0.purchase_date >= fourWeeksAgo && $0.purchase_date < startOfWeek }

        guard !priorReceipts.isEmpty else { return nil }

        let priorTotal = priorReceipts.reduce(0) { $0 + $1.total_amount }
        let weekCount = max(1, calendar.dateComponents([.weekOfYear], from: fourWeeksAgo, to: startOfWeek).weekOfYear ?? 1)
        let avgWeekly = priorTotal / Double(weekCount)

        guard avgWeekly > 0, thisWeekTotal > avgWeekly * 1.3 else { return nil }

        let pctIncrease = Int(((thisWeekTotal - avgWeekly) / avgWeekly) * 100)

        // Find top spending category this week
        let thisWeekReceipts = receipts.filter { $0.purchase_date >= startOfWeek }
        let topCategory = findTopCategory(in: thisWeekReceipts)

        return Insight(
            id: UUID(),
            type: .spendingSpike,
            title: "Spending Up \(pctIncrease)%",
            message: "You've spent \(pctIncrease)% more this week than your average\(topCategory.map { ", mostly on \($0)" } ?? "").",
            date: now,
            isRead: false,
            category: topCategory,
            amount: thisWeekTotal
        )
    }

    // MARK: - Category Milestone Detection

    private func detectCategoryMilestones(receipts: [Receipt]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now

        let thisMonthReceipts = receipts.filter { $0.purchase_date >= startOfMonth }

        // Group by category
        var categoryTotals: [String: Double] = [:]
        for receipt in thisMonthReceipts {
            for item in receipt.items {
                categoryTotals[item.category, default: 0] += item.price
            }
        }

        // Check milestones at $100, $250, $500, $1000
        let milestones: [Double] = [100, 250, 500, 1000]
        var results: [Insight] = []

        for (category, total) in categoryTotals {
            for milestone in milestones where total >= milestone {
                // Only report the highest milestone crossed
                let nextMilestone = milestones.first { $0 > milestone }
                if let next = nextMilestone, total >= next { continue }

                results.append(Insight(
                    id: UUID(),
                    type: .categoryMilestone,
                    title: "\(category): $\(Int(milestone))+",
                    message: "You've spent $\(Int(total)) on \(category) this month.",
                    date: now,
                    isRead: false,
                    category: category,
                    amount: total
                ))
            }
        }

        return results
    }

    // MARK: - Weekly Summary Notification

    /// Reschedule the Sunday 10am notification with the latest spending data.
    func rescheduleWeeklySummary(receipts: [Receipt]) {
        guard SubscriptionManager.shared.isPlus else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])

        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeekTotal = receipts
            .filter { $0.purchase_date >= startOfWeek }
            .reduce(0) { $0 + $1.total_amount }

        let topCategory = findTopCategory(in: receipts.filter { $0.purchase_date >= startOfWeek })
        let message = topCategory != nil
            ? "You spent $\(String(format: "%.0f", thisWeekTotal)) this week. Top category: \(topCategory!)."
            : "You spent $\(String(format: "%.0f", thisWeekTotal)) this week."

        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Summary"
        content.body = message
        content.sound = .default

        // Sunday at 10am local time
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error {
                print("⚠️ [Insights] Failed to schedule weekly summary: \(error)")
            }
        }
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(for insight: Insight) {
        let content = UNMutableNotificationContent()
        content.title = insight.title
        content.body = insight.message
        content.sound = .default

        // Fire in 5 seconds (immediate-ish, but not synchronous)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: insight.id.uuidString, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    // MARK: - Helpers

    private func findTopCategory(in receipts: [Receipt]) -> String? {
        var categoryTotals: [String: Double] = [:]
        for receipt in receipts {
            for item in receipt.items {
                categoryTotals[item.category, default: 0] += abs(item.price)
            }
        }
        return categoryTotals.max(by: { $0.value < $1.value })?.key
    }

    func markAsRead(_ insight: Insight) {
        if let index = insights.firstIndex(where: { $0.id == insight.id }) {
            insights[index].isRead = true
            save()
        }
    }

    private func pruneOldInsights() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        insights.removeAll { $0.date < cutoff }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(insights) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Insight].self, from: data) {
            insights = decoded
        }
    }
}
