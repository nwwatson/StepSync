import Foundation
import CoreLocation
import Observation

@Observable
public final class LocationManager: NSObject, @unchecked Sendable {
    public static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public private(set) var currentLocation: CLLocation?
    public private(set) var isTracking = false
    public private(set) var routePoints: [CLLocation] = []
    public private(set) var totalDistance: Double = 0
    public private(set) var currentSpeed: Double = 0
    public private(set) var currentAltitude: Double = 0
    public private(set) var elevationGain: Double = 0

    private var previousAltitude: Double?
    private var locationUpdateHandler: ((CLLocation) -> Void)?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        #if os(iOS)
        locationManager.pausesLocationUpdatesAutomatically = false
        #endif
    }

    private func configureBackgroundUpdates() {
        #if os(iOS)
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        #endif
    }

    public func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    public func startTracking(updateHandler: ((CLLocation) -> Void)? = nil) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }

        locationUpdateHandler = updateHandler
        routePoints = []
        totalDistance = 0
        elevationGain = 0
        previousAltitude = nil
        isTracking = true

        if authorizationStatus == .authorizedAlways {
            configureBackgroundUpdates()
        }

        locationManager.startUpdatingLocation()
    }

    public func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationUpdateHandler = nil
    }

    public func getRouteCoordinates() -> [(latitude: Double, longitude: Double)] {
        routePoints.map { ($0.coordinate.latitude, $0.coordinate.longitude) }
    }

    private func processLocation(_ location: CLLocation) {
        currentLocation = location
        currentSpeed = max(location.speed, 0)
        currentAltitude = location.altitude

        if location.horizontalAccuracy <= 20 {
            if let lastPoint = routePoints.last {
                let distance = location.distance(from: lastPoint)
                if distance >= 5 {
                    totalDistance += distance
                    routePoints.append(location)

                    if let prevAlt = previousAltitude {
                        let altitudeChange = location.altitude - prevAlt
                        if altitudeChange > 0 {
                            elevationGain += altitudeChange
                        }
                    }
                    previousAltitude = location.altitude
                }
            } else {
                routePoints.append(location)
                previousAltitude = location.altitude
            }
        }

        locationUpdateHandler?(location)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for location in locations {
            processLocation(location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
}
