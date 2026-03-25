//
//  AppConstants.swift
//  SpendSmart
//
//  Central location for app-wide constants. Update these values before App Store submission.
//

import Foundation

enum AppConstants {
    // MARK: - App Info
    static let appName = "SpendSmart"
    static let appStoreId = "6745190294"

    // MARK: - Website URLs
    static let websiteBaseURL = "https://spendsmart.vercel.app"
    
    // Safe: compile-time string literals never fail URL(string:)
    nonisolated(unsafe) static let privacyPolicyURL = URL(string: "https://spendsmart.vercel.app/privacy")!
    nonisolated(unsafe) static let termsOfServiceURL = URL(string: "https://spendsmart.vercel.app/terms")!
    
    static var supportEmail: String {
        "support@spendsmart.app"
    }
    
    // MARK: - Subscription
    static let freeScansPerWeek = 5
    
    // MARK: - Feature Flags
    static let isDebugMode = false // Set to false for production
}
