import Foundation

enum AppFormatters {
    private static let currencyLock = NSLock()
    private static var currencyCache: [String: NumberFormatter] = [:]

    static func currency(code: String?, maximumFractionDigits: Int = 2) -> NumberFormatter {
        let resolved = (code?.isEmpty == false) ? code! : "USD"
        let cacheKey = "\(resolved)|\(maximumFractionDigits)"
        currencyLock.lock()
        defer { currencyLock.unlock() }

        if let cached = currencyCache[cacheKey] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = resolved
        formatter.minimumFractionDigits = maximumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.locale = .current
        currencyCache[cacheKey] = formatter
        return formatter
    }

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .current
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = .current
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = .current
        return formatter
    }()

    static let shortWeekdaySymbols: [String] = {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols ?? []
    }()
}
