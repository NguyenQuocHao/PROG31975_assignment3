//
//  ContentView.swift
//  LocationServiceDemo
//
//  Created by Default User on 11/5/25.
//

import CoreLocation
import MapKit
import SwiftUI

enum Field: String, Hashable {
    case finalDestination = "Destination"
    case stop1 = "Stop 1"
    case stop2 = "Stop 2"
}

struct ContentView: View {
    @ObservedObject var locationManagerVM = MyAppLocationManagerVM()
    @State var camPosition: MapCameraPosition = .userLocation(
        fallback: .automatic
    )
    @State var finalDestination = ""
    @State var stop1 = ""
    @State var stop2 = ""
    @State var selection: MKMapItem?
//    @State var route: MKRoute?
    @State var routes: [Path: MKRoute?] = [
        .startToFinish: nil,
        .startToStop1: nil,
        .stop1ToStop2: nil,
    ]
    @State var locations: [Field: MKMapItem] = [:]

    @State private var selectedPath: Path = .startToFinish
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack {
            Button("Reset") {
                locationManagerVM.mapItems.removeAll()
                for key in routes.keys {
                    routes[key] = nil
                }
                
                locations = [:]
            }

            Text("Select path")
            Picker("", selection: $selectedPath) {
                ForEach(Path.allCases.prefix(3), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .onChange(of: selectedPath) { oldValue, newValue in
                locationManagerVM.mapItems.removeAll()
                Task {
                    await showRouteToLocation(selectedPath)
                }
            }

            TextField("Final Destination", text: $finalDestination)
                .focused($focusedField, equals: .finalDestination)

            TextField("Stop 1", text: $stop1)
                .focused($focusedField, equals: .stop1)

            TextField("Stop 2", text: $stop2)
                .focused($focusedField, equals: .stop2)

            Button("Locate") {
                findLocation()
            }
            
            Button("Find route") {
                Task {
                    await showRouteToLocation(selectedPath)
                }
            }

            ForEach(locationManagerVM.mapItems.prefix(3), id: \.self) { item in
                Text("\(item.name ?? ""): \(item.placemark.title ?? "")")
            }

            if let mk = routes[.startToFinish] {
                if let mk1 = mk {
                    Text("Steps:")

                    ForEach(mk1.steps, id: \.self) { item in
                        Text(item.instructions)
                    }
                }
            }

            Map(position: $camPosition, selection: $selection) {
                if let curLocation = locationManagerVM.curLocation {
                    Marker("You're here", coordinate: curLocation)
                }

                ForEach(locationManagerVM.mapItems, id: \.self) { item in
                    Marker(item: item)
                }

                ForEach(Array(locations.keys), id: \.self) { key in
                    Marker("\(key.rawValue): \(locations[key]?.name ?? "")", coordinate: locations[key]!.placemark.coordinate)
                }

                if let mk = routes[.startToStop1] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.purple, style: StrokeStyle(lineWidth: 5))
                    }
                }
                if let mk = routes[.stop1ToStop2] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.green, style: StrokeStyle(lineWidth: 5))
                    }
                }
                if let mk = routes[.stop2ToDestination] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.blue, style: StrokeStyle(lineWidth: 5))
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapScaleView()
                MapUserLocationButton()
            }
            .task(id: selection) {
                locationManagerVM.mapItems.removeAll()

                if let unwrapped = focusedField {
                    locations[unwrapped] = selection
                }

//                await showRouteToLocation(selection, selectedPath)
            }
        }
        .padding()
    }

    func saveLocation() {
        switch focusedField {
        case .finalDestination:
            locations[.finalDestination] = selection
        case .stop1:
            locationManagerVM.searchLoaction(name: stop1)
        case .stop2:
            locationManagerVM.searchLoaction(name: stop2)
        default:
            return
        }
    }

    func findLocation() {
        switch focusedField {
        case .finalDestination:
            locationManagerVM.searchLoaction(name: finalDestination)
        case .stop1:
            locationManagerVM.searchLoaction(name: stop1)
        case .stop2:
            locationManagerVM.searchLoaction(name: stop2)
        default:
            return
        }
    }
    
    func getSourceLocation(_ path: Path) -> CLLocationCoordinate2D? {
        switch path {
        case .stop1ToStop2:
            return locations[.stop1]?.placemark.coordinate
        case .stop2ToDestination:
            return locations[.stop2]?.placemark.coordinate
        case .startToFinish:
            if locations[.stop2] != nil {
                return locations[.stop2]?.placemark.coordinate
            }
            else if locations[.stop1] != nil {
                return locations[.stop1]?.placemark.coordinate
            }
            else {
                return locationManagerVM.curLocation
            }
        case .startToStop1:
            return locationManagerVM.curLocation
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

    func showRouteToLocation(_ path: Path) async {
        guard let curLocation = locationManagerVM.curLocation
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
        case .startToStop1:
            fallthrough
        case .stop1ToStop2:
            fallthrough
        case .stop2ToDestination:
            let source = getSourceLocation(path)
            if let unwrappedSource = source {
                request.source = MKMapItem(
                    placemark: .init(
                        coordinate: unwrappedSource
                    )
                )
            }
            else {
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
        }
        else {
            return
        }

        do {
            let response = try await MKDirections(request: request).calculate()
            
            self.routes[path] = response.routes.first

            if let rect = routes[path]??.polyline.boundingMapRect {
                camPosition = .rect(rect)
            }
        } catch {
            print("error \(error)")
        }
    }
}

#Preview {
    ContentView()
}
