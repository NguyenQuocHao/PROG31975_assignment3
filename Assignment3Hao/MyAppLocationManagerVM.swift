// Code by Hao Nguyen, 991521091

import CoreLocation
import Foundation
import MapKit
import SwiftUI

class MyAppLocationManagerVM: NSObject, CLLocationManagerDelegate,
    ObservableObject
{
    public let torontoCoordinate = CLLocationCoordinate2D(
        latitude: 43.6532,
        longitude: -79.3832
    )

    let locationMange = CLLocationManager()
    
    @Published var isLoadingLocation = false
    @Published var showDenyAlert = false
    @Published var noLocationsFound = false
    @Published var isSearching = false

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var routes: [Path: MKRoute?] = [
//        .startToFinish: nil,
        .startToStop1: nil,
        .stop1ToStop2: nil,
        .stop2ToDestination: nil,
    ]
    @Published var locations: [Field: MKMapItem] = [:]
    @Published var curLocation: CLLocationCoordinate2D?
    @Published var mapItems: [MKMapItem] = []
    @Published var camPosition: MapCameraPosition

    override init() {
        let torontoCoordinate = CLLocationCoordinate2D(
            latitude: 43.6532,
            longitude: -79.3832
        )

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

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let location = locations.last {
            print(
                "Location: \(location.coordinate.latitude), \(location.coordinate.longitude) "
            )

            curLocation = location.coordinate
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            print("Authorization not determined")
        case .restricted:
            print("Authorization restricted")
            fallthrough
        case .denied:
            print("Authorization denied")
            showDenyAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            print("Authorized — starting location updates")
            manager.startUpdatingLocation()
        @unknown default:
            break
        }
    }

    func searchLoaction(name: String?) {
        guard let name = name, let curLocation = curLocation else {
            print("invalid name")
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region.center = curLocation

        let search = MKLocalSearch(request: request)

        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("Search failed: \(error.localizedDescription)")
                    self.noLocationsFound = true
                    return
                }
                
                guard let res = response else {
                    self.noLocationsFound = true
                    print("Location not found")
                    return
                }
                
                if res.mapItems.isEmpty {
                    self.noLocationsFound = true
                    print("Location not found")
                } else {
                    self.noLocationsFound = false
                    self.mapItems = res.mapItems
                }
            }
        }
    }

    func findLocation(
        focusedField: Field?,
        finalDestination: String,
        stop1: String,
        stop2: String
    ) {
        switch focusedField {
        case .finalDestination:
            searchLoaction(name: finalDestination)
        case .stop1:
            searchLoaction(name: stop1)
        case .stop2:
            searchLoaction(name: stop2)
        default:
            return
        }
    }

    func getDestinationLocation(_ path: Path) -> CLLocationCoordinate2D? {
        switch path {
        case .stop1ToStop2:
            return locations[.stop2]?.placemark.coordinate
        case .stop2ToDestination:
            return locations[.finalDestination]?.placemark.coordinate
        case .startToFinish:
            return locations[.finalDestination]?.placemark.coordinate
        case .startToStop1:
            return locations[.stop1]?.placemark.coordinate
        }
    }

    func getSourceLocation(_ path: Path) -> CLLocationCoordinate2D? {
        switch path {
        case .stop1ToStop2:
            return locations[.stop1]?.placemark.coordinate
        case .stop2ToDestination:
            if locations[.stop2] != nil {
                return locations[.stop2]?.placemark.coordinate
            } else if locations[.stop1] != nil {
                return locations[.stop1]?.placemark.coordinate
            } else {
                return curLocation
            }
        case .startToFinish:
            if locations[.stop2] != nil {
                return locations[.stop2]?.placemark.coordinate
            } else if locations[.stop1] != nil {
                return locations[.stop1]?.placemark.coordinate
            } else {
                return curLocation
            }
        case .startToStop1:
            return curLocation
        }
    }

    func showRouteToLocation(_ path: Path) async {
        guard let curLocation = curLocation
        else {
            return
        }

        let request = MKDirections.Request()

        switch path {
        case .startToFinish:
            if locations[.stop1] != nil {
                await showRouteToLocation(.startToStop1)
            }

            if locations[.stop2] != nil {
                await showRouteToLocation(.stop1ToStop2)
            }

            if locations[.finalDestination] != nil {
                await showRouteToLocation(.stop2ToDestination)
            }
        case .startToStop1, .stop1ToStop2, .stop2ToDestination:
            let source = getSourceLocation(path)
            if let unwrappedSource = source {
                request.source = MKMapItem(
                    placemark: .init(
                        coordinate: unwrappedSource
                    )
                )
            } else {
                return
            }
        }

        let destination = getDestinationLocation(path)
        if let unwrappedDestination = destination {
            request.destination = MKMapItem(
                placemark: .init(
                    coordinate: unwrappedDestination
                )
            )
        } else {
            return
        }

        do {
            self.isSearching = true

            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            directions.calculate { response, error in
                DispatchQueue.main.async {
                    self.isSearching = false
                    
                    if let error = error {
                        print("Directions error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let route = response?.routes.first else {
                        return
                    }
                    
                    self.routes[path] = route
                }
            }

//            self.routes[path] = response.routes.first

            if let rect = routes[path]??.polyline.boundingMapRect {
                camPosition = .rect(rect)
            }
        } catch {
            print("error \(error)")
        }
    }
}
