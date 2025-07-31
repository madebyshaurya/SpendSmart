//
//  VersionInfo.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation

// MARK: - Version Information Models

/// Represents version information from the App Store
struct VersionInfo: Equatable {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String?
    let releaseDate: Date?
    let isUpdateAvailable: Bool
    let appStoreURL: String?
    let minimumOSVersion: String?
    let isForced: Bool // New: indicates if this update is mandatory
    
    init(currentVersion: String, latestVersion: String, releaseNotes: String? = nil, releaseDate: Date? = nil, appStoreURL: String? = nil, minimumOSVersion: String? = nil, isForced: Bool = false) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
        self.releaseDate = releaseDate
        self.appStoreURL = appStoreURL
        self.minimumOSVersion = minimumOSVersion
        self.isForced = isForced
        self.isUpdateAvailable = Self.compareVersions(current: currentVersion, latest: latestVersion)
    }
    
    /// Compare version strings to determine if an update is available
    private static func compareVersions(current: String, latest: String) -> Bool {
        print("🔄 Comparing versions - Current: \(current), Latest: \(latest)")
        
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        // If we couldn't parse the versions, assume no update needed
        guard !currentComponents.isEmpty && !latestComponents.isEmpty else {
            print("⚠️ Could not parse version numbers")
            return false
        }
        
        let maxCount = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxCount {
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            let latestValue = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestValue > currentValue {
                print("✅ Update available: \(latest) > \(current)")
                return true
            } else if latestValue < currentValue {
                print("ℹ️ Current version is newer: \(current) > \(latest)")
                return false
            }
        }
        
        print("ℹ️ Versions are equal: \(current) = \(latest)")
        return false // Versions are equal
    }
    
    /// Check if the current OS version meets the minimum requirement
    func isOSVersionCompatible() -> Bool {
        guard let minimumOS = minimumOSVersion else { return true }
        
        let currentOS = ProcessInfo.processInfo.operatingSystemVersion
        let currentOSString = "\(currentOS.majorVersion).\(currentOS.minorVersion).\(currentOS.patchVersion)"
        
        return Self.compareVersions(current: currentOSString, latest: minimumOS)
    }
}

// MARK: - App Store API Response Models

/// Response from iTunes Search API
struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

/// Individual app result from iTunes Search API
struct AppStoreResult: Codable {
    let bundleId: String
    let version: String
    let releaseNotes: String?
    let currentVersionReleaseDate: String
    let trackViewUrl: String?
    let minimumOsVersion: String
    
    private enum CodingKeys: String, CodingKey {
        case bundleId
        case version
        case releaseNotes
        case currentVersionReleaseDate
        case trackViewUrl
        case minimumOsVersion
    }
}

// MARK: - Version Update Action Types

/// Actions user can take when presented with version update
enum VersionUpdateAction: Equatable {
    case updateNow
    case remindLater
    case dismiss
}

// MARK: - Version Check Result

/// Result of a version check operation
enum VersionCheckResult: Equatable {
    case updateAvailable(VersionInfo)
    case forcedUpdateRequired(VersionInfo) // New: indicates a mandatory update
    case upToDate
    case error(Error)
    case remindLater(Date) // User chose remind later, with date
    
    static func == (lhs: VersionCheckResult, rhs: VersionCheckResult) -> Bool {
        switch (lhs, rhs) {
        case (.upToDate, .upToDate):
            return true
        case (.updateAvailable(let lhsInfo), .updateAvailable(let rhsInfo)):
            return lhsInfo == rhsInfo
        case (.forcedUpdateRequired(let lhsInfo), .forcedUpdateRequired(let rhsInfo)):
            return lhsInfo == rhsInfo
        case (.remindLater(let lhsDate), .remindLater(let rhsDate)):
            return lhsDate == rhsDate
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Version Check Errors

/// Errors that can occur during version checking
enum VersionCheckError: LocalizedError, Equatable {
    case networkError
    case invalidResponse
    case appNotFound
    case invalidBundleId
    case parsingError
    case incompatibleOSVersion
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to check for updates. Please check your internet connection."
        case .invalidResponse:
            return "Received invalid response from App Store."
        case .appNotFound:
            return "App not found in App Store."
        case .invalidBundleId:
            return "Invalid app bundle identifier."
        case .parsingError:
            return "Error parsing version information."
        case .incompatibleOSVersion:
            return "This update requires a newer version of iOS."
        }
    }
    
    static func == (lhs: VersionCheckError, rhs: VersionCheckError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.invalidResponse, .invalidResponse),
             (.appNotFound, .appNotFound),
             (.invalidBundleId, .invalidBundleId),
             (.parsingError, .parsingError),
             (.incompatibleOSVersion, .incompatibleOSVersion):
            return true
        default:
            return false
        }
    }
}
