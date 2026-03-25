import SwiftUI

/// Shows the user's scanning streak — consecutive days/weeks with at least one scan.
/// Inspired by Duolingo's streak system. Creates a habit loop through positive reinforcement.
struct ScanStreakView: View {
    @AppStorage("scanStreakCount") private var streakCount = 0
    @AppStorage("scanStreakLastDate") private var lastScanDateString = ""
    @AppStorage("scanStreakBestEver") private var bestStreak = 0

    @State private var isAnimating = false
    @State private var showFlame = false

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon with animation
            ZStack {
                if streakCount > 0 {
                    // Glow behind flame
                    Circle()
                        .fill(flameColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .scaleEffect(isAnimating ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                    Image(systemName: streakCount >= 7 ? "flame.fill" : "flame")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(flameColor)
                        .symbolEffect(.bounce, value: showFlame)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                if streakCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(streakCount)")
                            .font(.ibmPlexMono(size: 20))
                            .fontWeight(.bold)
                            .foregroundStyle(flameColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text(streakCount == 1 ? "day streak" : "day streak")
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundStyle(Color.brandTextSecondary)
                    }

                    if bestStreak > streakCount {
                        Text("Best: \(bestStreak) days")
                            .font(.manrope(size: 11, weight: .regular))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                } else {
                    Text("Start a streak!")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                    Text("Scan a receipt to begin")
                        .font(.manrope(size: 11, weight: .regular))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }

            Spacer()

            // Week dots (last 7 days)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    Circle()
                        .fill(isDayActive(daysAgo: 6 - dayOffset) ? flameColor : Color.brandBorder)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isDayActive(daysAgo: 6 - dayOffset) ? 1.0 : 0.7)
                        .animation(.brandBouncy.delay(Double(dayOffset) * 0.05), value: streakCount)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(streakCount > 0 ? flameColor.opacity(0.2) : Color.brandBorder, lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showFlame = true
            }
        }
    }

    // MARK: - Streak Logic

    /// Call this when a receipt is saved to update the streak.
    static func recordScan() {
        let defaults = UserDefaults.standard
        let today = Self.dateString(for: Date())
        let lastDate = defaults.string(forKey: "scanStreakLastDate") ?? ""

        if lastDate == today {
            // Already scanned today, streak unchanged
            return
        }

        let yesterday = Self.dateString(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        if lastDate == yesterday {
            // Consecutive day — extend streak
            let current = defaults.integer(forKey: "scanStreakCount") + 1
            defaults.set(current, forKey: "scanStreakCount")
            let best = defaults.integer(forKey: "scanStreakBestEver")
            if current > best {
                defaults.set(current, forKey: "scanStreakBestEver")
            }
        } else if lastDate.isEmpty {
            // First ever scan
            defaults.set(1, forKey: "scanStreakCount")
            defaults.set(1, forKey: "scanStreakBestEver")
        } else {
            // Streak broken — restart at 1
            defaults.set(1, forKey: "scanStreakCount")
        }

        defaults.set(today, forKey: "scanStreakLastDate")

        // Store today in the weekly history
        var weekHistory = defaults.array(forKey: "scanStreakWeekHistory") as? [String] ?? []
        if !weekHistory.contains(today) {
            weekHistory.append(today)
            // Keep only last 7 days
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            weekHistory = weekHistory.filter { dateStr in
                if let date = Self.parseDate(dateStr) {
                    return date >= sevenDaysAgo
                }
                return false
            }
            defaults.set(weekHistory, forKey: "scanStreakWeekHistory")
        }
    }

    // MARK: - Helpers

    private var flameColor: Color {
        switch streakCount {
        case 0: return .brandTextTertiary
        case 1...3: return .orange
        case 4...6: return .orange
        case 7...13: return Color(red: 1.0, green: 0.4, blue: 0.1) // deep orange
        default: return .red // 14+ days — on fire
        }
    }

    private func isDayActive(daysAgo: Int) -> Bool {
        let targetDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let targetString = Self.dateString(for: targetDate)
        let weekHistory = UserDefaults.standard.array(forKey: "scanStreakWeekHistory") as? [String] ?? []
        return weekHistory.contains(targetString)
    }

    private static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
