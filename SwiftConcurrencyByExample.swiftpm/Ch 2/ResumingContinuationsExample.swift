//
//  ResumingContinuationsExample.swift
//  
//
//  Created by Fleshman, Jeremy on 12/4/22.
//

import SwiftUI
import CoreLocation // to read the location
import CoreLocationUI // to use SwiftUI's LocationButton for a standardized UI

/// LocationManager stub class with a stored continuation to track whether we have a location coordinate or an error
@MainActor // avoid updating the UI on a bg thread
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Error>?
    let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    /// async location requesting method where we store our continuation on the LocationManager object
    func requestLocation() async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.first?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
    }

}

struct ResumingContinuationsView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var currentLocation = "Tap above to get your current location coordinates!"
    @State private var isButtonDisabled = false

    var body: some View {
        VStack {
            LocationButton {
                isButtonDisabled = true
                Task {
                    if let location = try? await locationManager.requestLocation() {
                        print("Location: \(location)")
                        currentLocation = "Latitude: \(location.latitude)\n"
                                        + "Longitude: \(location.longitude)"
                    } else {
                        print("Unknown location")
                        currentLocation = "Unknown location"
                    }
                    isButtonDisabled = false
                }
            }
            .frame(height: 44)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding()
            .disabled(isButtonDisabled)

            Label {
                Text(currentLocation)
            } icon: {
                Image(systemName: "location.magnifyingglass")
            }
            .font(.subheadline)
        }
    }
}

struct ResumingContinuationsView_Previews: PreviewProvider {
    static var previews: some View {
        ResumingContinuationsView()
    }
}
