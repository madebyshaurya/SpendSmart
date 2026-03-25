import SwiftUI

/// Time range filter used across Dashboard views
enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "3 Months"
    case year = "This Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        case .threeMonths: return "calendar.badge.exclamationmark"
        case .year: return "calendar.circle"
        case .allTime: return "infinity"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }
}

/// Native Menu-based time range picker replacing BrandDropdown
struct TimeRangeMenu: View {
    @Binding var selection: TimeRange

    var body: some View {
        Menu {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selection = range
                    }
                    HapticManager.shared.selection()
                } label: {
                    Label(range.rawValue, systemImage: range.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selection.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(selection.rawValue)
                    .font(.manrope(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.brandVibrantBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.brandAccentLight)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
