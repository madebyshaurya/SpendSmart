//
//  VersionInfo.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation

// MARK: - Version Information Models

/// Represents version information from the App Store
struct VersionInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String?
    let releaseDate: Date?
    let isUpdateAvailable: Bool
    let appStoreURL: String?
    
    init(currentVersion: String, latestVersion: String, releaseNotes: String? = nil, releaseDate: Date? = nil, appStoreURL: String? = nil) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
        self.releaseDate = releaseDate
        self.appStoreURL = appStoreURL
        self.isUpdateAvailable = Self.compareVersions(current: currentVersion, latest: latestVersion)
    }
    
    /// Compare version strings to determine if an update is available
    private static func compareVersions(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxCount {
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            let latestValue = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestValue > currentValue {
                return true
            } else if latestValue < currentValue {
                return false
            }
        }
        
        return false // Versions are equal
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
enum VersionUpdateAction {
    case updateNow
    case remindLater
    case skipVersion
    case dismiss
}

// MARK: - Version Check Result

/// Result of a version check operation
enum VersionCheckResult {
    case updateAvailable(VersionInfo)
    case upToDate
    case error(Error)
    case skipped(String) // Version was previously skipped
    case remindLater(Date) // User chose remind later, with date
}

// MARK: - Version Check Errors

/// Errors that can occur during version checking
enum VersionCheckError: LocalizedError {
    case networkError
    case invalidResponse
    case appNotFound
    case invalidBundleId
    case parsingError
    
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
        }
    }
}
