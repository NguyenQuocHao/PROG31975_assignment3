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

    @State var finalDestination = ""
    @State var stop1 = ""
    @State var stop2 = ""
    @State var selection: MKMapItem?

    @State private var selectedPath: Path = .startToFinish
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Reset") {
                    locationManagerVM.mapItems.removeAll()
                    for key in locationManagerVM.routes.keys {
                        locationManagerVM.routes[key] = nil
                    }
                    
                    locationManagerVM.locations = [:]
                }
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
                    await locationManagerVM.showRouteToLocation(selectedPath)
                }
            }

            TextField("Final Destination", text: $finalDestination)
                .focused($focusedField, equals: .finalDestination)

            TextField("Stop 1", text: $stop1)
                .focused($focusedField, equals: .stop1)

            TextField("Stop 2", text: $stop2)
                .focused($focusedField, equals: .stop2)

            Button("Locate") {
                locationManagerVM.findLocation(focusedField: focusedField, finalDestination: finalDestination, stop1: stop1, stop2: stop2)
            }
            
            Button("Find route") {
                Task {
                    await locationManagerVM.showRouteToLocation(selectedPath)
                }
            }

            ForEach(locationManagerVM.mapItems.prefix(2), id: \.self) { item in
                Text("\(item.name ?? ""): \(item.placemark.title ?? "")")
            }
            
            if locationManagerVM.routes.contains(where: { $0.value != nil }) {
                ScrollView(.vertical) {
                    VStack {
                        Text("Steps:")

                        if selectedPath == .startToFinish {
                            ForEach(Array(locationManagerVM.routes.values), id: \.self) { item in
                                if let mk = item {
                                    Text("To \(mk.name):")

                                    ForEach(mk.steps, id: \.self) { item in
                                        Text(item.instructions)
                                    }
                                }
                            }
                        }
                        else if let mk = locationManagerVM.routes[selectedPath] {
                            if let mk1 = mk {
                                ForEach(mk1.steps, id: \.self) { item in
                                    Text(item.instructions)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
            }


            Map(position: $locationManagerVM.camPosition, selection: $selection) {
                if let curLocation = locationManagerVM.curLocation {
                    Marker("You're here", coordinate: curLocation)
                }

                ForEach(locationManagerVM.mapItems, id: \.self) { item in
                    Marker(item: item)
                }

                ForEach(Array(locationManagerVM.locations.keys), id: \.self) { key in
                    Marker("\(key.rawValue): \(locationManagerVM.locations[key]?.name ?? "")", coordinate: locationManagerVM.locations[key]!.placemark.coordinate)
                }

                if let mk = locationManagerVM.routes[.startToStop1] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.purple, style: StrokeStyle(lineWidth: 5))
                    }
                }
                if let mk = locationManagerVM.routes[.stop1ToStop2] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.green, style: StrokeStyle(lineWidth: 5))
                    }
                }
                if let mk = locationManagerVM.routes[.stop2ToDestination] {
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
                if let unwrappedSelection = selection  {
                    let index2 = locationManagerVM.locations.values.firstIndex(where: { $0.name == unwrappedSelection.name })
                    print(index2)

                    if let index = locationManagerVM.locations.values.firstIndex(where: { $0.identifier == unwrappedSelection.identifier })  {
                        print(index)
                        locationManagerVM.locations.remove(at:index)
                    }
                    else {
                        locationManagerVM.mapItems.removeAll()

                        if let unwrapped = focusedField {
                            locationManagerVM.locations[unwrapped] = unwrappedSelection
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
