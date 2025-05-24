//
//  UserLocationManager.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import Foundation
import CoreLocation
import MapKit
import Combine

/// A class that manages the user's current location
class UserLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = UserLocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update location when user moves 50 meters
    }
    
    /// Request location permission and start updating location
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start updating the user's location
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    /// Stop updating the user's location
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Get the user's current coordinate or a default if not available
    func getCurrentCoordinate() -> CLLocationCoordinate2D {
        if let location = userLocation {
            return location.coordinate
        } else {
            // Default to San Francisco only if user location is not available
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            // Handle denied or restricted permission
            locationError = NSError(domain: "UserLocationManager", 
                                   code: 1, 
                                   userInfo: [NSLocalizedDescriptionKey: "Location permission denied"])
            stopUpdatingLocation()
        case .notDetermined:
            // Wait for user to make a choice
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
        print("Location manager error: \(error.localizedDescription)")
    }
}
