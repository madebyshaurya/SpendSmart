import Foundation

struct VersionInfo: Equatable {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String?
    let releaseDate: Date?
    let isUpdateAvailable: Bool
    let appStoreURL: String?
    let minimumOSVersion: String?
    let isForced: Bool
    
    init(currentVersion: String, latestVersion: String, releaseNotes: String? = nil, releaseDate: Date? = nil, appStoreURL: String? = nil, minimumOSVersion: String? = nil, isForced: Bool = false) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
        self.releaseDate = releaseDate
        self.appStoreURL = appStoreURL
        self.minimumOSVersion = minimumOSVersion
        self.isForced = isForced
        self.isUpdateAvailable = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }
    
    func isOSVersionCompatible() -> Bool {
        guard let minimumOS = minimumOSVersion else { return true }
        let currentOS = ProcessInfo.processInfo.operatingSystemVersion
        let currentOSString = "\(currentOS.majorVersion).\(currentOS.minorVersion).\(currentOS.patchVersion)"
        return currentOSString.compare(minimumOS, options: .numeric) != .orderedAscending
    }
}

struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

struct AppStoreResult: Codable {
    let bundleId: String
    let version: String
    let releaseNotes: String?
    let currentVersionReleaseDate: String
    let trackViewUrl: String?
    let minimumOsVersion: String
}

enum VersionUpdateAction: Equatable {
    case updateNow, remindLater, dismiss
}

enum VersionCheckResult: Equatable {
    case updateAvailable(VersionInfo)
    case forcedUpdateRequired(VersionInfo)
    case upToDate
    case error(Error)
    case remindLater(Date)
    
    static func == (lhs: VersionCheckResult, rhs: VersionCheckResult) -> Bool {
        switch (lhs, rhs) {
        case (.upToDate, .upToDate): return true
        case (.updateAvailable(let l), .updateAvailable(let r)): return l == r
        case (.forcedUpdateRequired(let l), .forcedUpdateRequired(let r)): return l == r
        case (.remindLater(let l), .remindLater(let r)): return l == r
        case (.error(let l), .error(let r)): return l.localizedDescription == r.localizedDescription
        default: return false
        }
    }
}

enum VersionCheckError: LocalizedError, Equatable {
    case networkError, invalidResponse, appNotFound, invalidBundleId, parsingError, incompatibleOSVersion
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Unable to check for updates. Please check your internet connection."
        case .invalidResponse: return "Received invalid response from App Store."
        case .appNotFound: return "App not found in App Store."
        case .invalidBundleId: return "Invalid app bundle identifier."
        case .parsingError: return "Error parsing version information."
        case .incompatibleOSVersion: return "This update requires a newer version of iOS."
        }
    }
}
