//
//  ContentView.swift
//  LocationServiceDemo
//
//  Created by Default User on 11/5/25.
//

import CoreLocation
import MapKit
import SwiftUI

enum Field: Hashable {
    case finalDestination
    case stop1
    case stop2
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
    @State var route: MKRoute?
    @State var routes: [Path: MKRoute?] = [
        .startToFinish: nil,
        .startToStop1: nil,
        .stop1ToStop2: nil,
    ]

    @State private var selectedPath: Path = .startToFinish
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack {
            Text("Select path")
            Picker("", selection: $selectedPath) {
                ForEach(Path.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .onChange(of: selectedPath) { oldValue, newValue in
                locationManagerVM.mapItems.removeAll()
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

            ForEach(locationManagerVM.mapItems.prefix(3), id: \.self) { item in
                Text("\(item.name ?? ""): \(item.placemark.title ?? "")")
                //                Button("Find route") {
                //                    Task {
                //                        await showRouteToLocation(item, selectedPath)
                //                    }
                //                }
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
                ForEach(locationManagerVM.mapItems, id: \.self) { item in
                    Marker(item: item)
                }

                if let mk = routes[.startToFinish] {
                    if let mk1 = mk {
                        MapPolyline(mk1.polyline)
                            .stroke(.blue, style: StrokeStyle(lineWidth: 5))
                    }
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
            }
            .task(id: selection) {
                locationManagerVM.mapItems.removeAll()

                await showRouteToLocation(selection, selectedPath)
            }
        }
        .padding()
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

    func showRouteToLocation(_ targetPlace: MKMapItem?, _ path: Path) async {
        guard let selection = selection,
            let curLocation = locationManagerVM.curLocation
        else {
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: .init(coordinate: curLocation))
        request.destination = selection

        do {
            let response = try await MKDirections(request: request).calculate()

            self.route = response.routes.first
            self.routes[path] = response.routes.first

            if let rect = route?.polyline.boundingMapRect {
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
