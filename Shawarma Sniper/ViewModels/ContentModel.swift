//
//  ContentModel.swift
//  Shawarma Sniper
//
//  Created by Uthman Mohamed on 2021-05-04.
//

import Foundation
import CoreLocation

class ContentModel: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    var locationManager = CLLocationManager()
    
    @Published var authorizationState = CLAuthorizationStatus.notDetermined
    
    @Published var restaurants = [Business]()
    
    @Published var placemark: CLPlacemark?
    
    override init() {
        super.init()
        
        // Set content model as the delegate of the location manager
        locationManager.delegate = self
        
    }
    
    func requestGeolocationPermission() {
        
        // Request permission from user
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Location Manager Delegate Methods
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        // Update authorization state for home view
        self.authorizationState = locationManager.authorizationStatus
        
        if locationManager.authorizationStatus == .authorizedAlways ||
            locationManager.authorizationStatus == .authorizedWhenInUse {
            
            // Start geolocating the user
            locationManager.startUpdatingLocation()
            
        } else if locationManager.authorizationStatus == .denied {
            // We don't have persmission
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Gives location of user
        let userLocation = locations.first
        
        // Get user placemark
        let geoCoder = CLGeocoder()
        
        geoCoder.reverseGeocodeLocation(userLocation!) { (placemarks, error) in
            if error == nil && placemarks != nil {
                self.placemark = placemarks?.first
            }
        }
        
        if userLocation != nil {
            // Stop requesting location after we get it once
            locationManager.stopUpdatingLocation()
            
            // Send location into Yelp API
            getBusinesses(location: userLocation!)
        }
        
        
    }
    
    // MARK: - Yelp API Methods
    func getBusinesses(location: CLLocation) {
        
        // Create URL
        //let urlString = URL(string: "https://api.yelp.com/v3/businesses/search?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&categories=\(category)&limit=6")
        
        var urlComponents = URLComponents(string: Constants.apiUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "term", value: "shawarma"),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        let url = urlComponents?.url
        
        if let url = url {
            
            // Create URL Request
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
            request.httpMethod = "GET"
            request.addValue("Bearer DRVmmezhHN9L614OU_m6BJKGcmDMf2Kq1pMbOpDXjMwN5kf8qyxXD4GueHH0_0xpJZIJUDQLt80PxPo8cgRZQgnPu5tANhahf4aN3xw1H6zTLCRmH9ZXCOhSWSWRYHYx", forHTTPHeaderField: "Authorization")
            
            // Get URLSession
            let session = URLSession.shared
            
            // Create Data Task
            session.dataTask(with: request) { (data, response, error) in
                if error == nil {
                    
                    // Parse json
                    do {
                        let result = try JSONDecoder().decode(BusinessSearch.self, from: data!)
                        
                        var sortedBusinesses = result.businesses
                        sortedBusinesses.sort { (b1, b2) in
                            return b1.distance ?? 0 < b2.distance ?? 0
                        }
                        
                        for business in sortedBusinesses {
                            business.getImageData()
                        }
                        
                        DispatchQueue.main.async {
                            self.restaurants = sortedBusinesses
                        }
                        
                    } catch {
                        print(error)
                    }
                }
            }.resume()
        }
    }
}
