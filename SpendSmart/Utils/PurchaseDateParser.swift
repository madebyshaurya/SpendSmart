import Foundation

enum PurchaseDateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: text) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: text) { return d }

        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: text) { return d }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy",
        ]

        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: text) { return d }
        }

        return nil
    }
}
