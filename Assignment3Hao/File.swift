//
//  File.swift
//  LocationServiceDemo
//
//  Created by Default User on 11/5/25.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

class MyAppLocationManagerVM : NSObject , CLLocationManagerDelegate , ObservableObject {
    public let torontoCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    let locationMange = CLLocationManager()
    
    @Published var curLocation : CLLocationCoordinate2D?
    
    @Published var mapItems :[MKMapItem] = []
    
    @Published var camPosition: MapCameraPosition
    @Published var locations: [Field: MKMapItem] = [:]

    override init() {
        let torontoCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
        
        let region = MKCoordinateRegion(
            center: torontoCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        self.camPosition = .userLocation(
            fallback: .region(region)
        )
        
        super.init()

        curLocation = torontoCoordinate
        locationMange.delegate = self
        locationMange.requestWhenInUseAuthorization()
        locationMange.startUpdatingLocation()
        
    }
    
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
    
//    func saveLocation() {
//        switch focusedField {
//        case .finalDestination:
//            locations[.finalDestination] = selection
//        case .stop1:
//            locationManagerVM.searchLoaction(name: stop1)
//        case .stop2:
//            locationManagerVM.searchLoaction(name: stop2)
//        default:
//            return
//        }
//    }
//    
//    func getDestinationLocation(_ path: Path) -> CLLocationCoordinate2D? {
//        switch path {
//        case .stop1ToStop2:
//            return locations[.stop2]?.placemark.coordinate
//        case .stop2ToDestination:
//            return locations[.finalDestination]?.placemark.coordinate
//        case .startToFinish:
//            return locations[.finalDestination]?.placemark.coordinate
//        case .startToStop1:
//            return locations[.stop1]?.placemark.coordinate
//        }
//    }
}
