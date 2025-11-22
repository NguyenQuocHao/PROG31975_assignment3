//
//  File.swift
//  LocationServiceDemo
//
//  Created by Default User on 11/5/25.
//

import Foundation
import CoreLocation
import MapKit

class MyAppLocationManagerVM : NSObject , CLLocationManagerDelegate , ObservableObject {
    
    let locationMange = CLLocationManager()
    
    @Published var curLocation : CLLocationCoordinate2D?
    
    @Published var mapItems :[MKMapItem] = []
    
    override init() {
        super.init()
        
        locationMange.delegate = self
        locationMange.requestWhenInUseAuthorization()
        locationMange.startUpdatingLocation()
        
    }
    
   // func
    func locationManager( _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        
        if let location = locations.last {
            
            print("Location: \(location.coordinate.latitude), \(location.coordinate.longitude) ")
            
            curLocation = location.coordinate
        }
    }
    
    func searchLoaction( name :String?){
        guard let name = name , let curLocation = curLocation else {
            print("invalid name")
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region.center = curLocation
        
        let search = MKLocalSearch(request: request)
        
        search.start{  response , error in
            guard let res = response else{
                print("Location not found")
                return
            }
            
            self.mapItems = res.mapItems
        }
    }
}
