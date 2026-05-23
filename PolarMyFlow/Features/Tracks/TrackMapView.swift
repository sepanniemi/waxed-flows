import MapKit
import SwiftUI

// MARK: - ColoredPolyline

final class ColoredPolyline: MKPolyline {
    var speedColor: UIColor = .white
    var isHalo: Bool = false
}

// MARK: - TrackMapView

struct TrackMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        // Non-interactive: scroll/zoom handled by the containing ScrollView + Slider
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        context.coordinator.buildOverlays(on: mapView, routePoints: routePoints)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.moveScrubDot(on: mapView, routePoints: routePoints, fraction: scrubFraction)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let scrubAnnotation = MKPointAnnotation()
        private var cachedRoutePoints: [RoutePoint] = []

        func buildOverlays(on mapView: MKMapView, routePoints: [RoutePoint]) {
            cachedRoutePoints = routePoints
            guard routePoints.count >= 2 else { return }

            let rawSpeeds = computeRawSpeeds(routePoints)
            let midTimes  = computeMidTimes(routePoints)
            let smoothed  = rollingMean(speeds: rawSpeeds, midTimes: midTimes)

            let minSpeed = smoothed.min() ?? 0
            let maxSpeed = max(minSpeed + 0.001, smoothed.max() ?? 1)

            let groups = buildSegments(waypoints: routePoints, smoothedSpeeds: smoothed,
                                       minSpeed: minSpeed, maxSpeed: maxSpeed)

            // Add halo pass first (underneath), crisp pass on top
            let halos: [ColoredPolyline] = groups.map { g in
                var coords = g.coords
                let p = ColoredPolyline(coordinates: &coords, count: coords.count)
                p.speedColor = SpeedColorRamp.color(for: g.normalizedSpeed)
                p.isHalo = true
                return p
            }
            let crisps: [ColoredPolyline] = groups.map { g in
                var coords = g.coords
                let p = ColoredPolyline(coordinates: &coords, count: coords.count)
                p.speedColor = SpeedColorRamp.color(for: g.normalizedSpeed)
                p.isHalo = false
                return p
            }
            mapView.addOverlays(halos, level: .aboveRoads)
            mapView.addOverlays(crisps, level: .aboveRoads)

            // Fit map rect to all waypoints with padding
            var rect = MKMapRect.null
            for p in routePoints {
                let pt = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
                rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
            }
            mapView.setVisibleMapRect(rect,
                edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                animated: false)

            // Initial scrub dot at start of route
            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: routePoints[0].latitude,
                longitude: routePoints[0].longitude)
            mapView.addAnnotation(scrubAnnotation)
        }

        func moveScrubDot(on mapView: MKMapView, routePoints: [RoutePoint], fraction: Double) {
            guard !cachedRoutePoints.isEmpty else { return }
            let idx = min(cachedRoutePoints.count - 1, max(0, Int(fraction * Double(cachedRoutePoints.count - 1))))
            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: cachedRoutePoints[idx].latitude,
                longitude: cachedRoutePoints[idx].longitude)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? ColoredPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            if polyline.isHalo {
                renderer.strokeColor = polyline.speedColor.withAlphaComponent(0.32)
                renderer.lineWidth = 12.0
            } else {
                renderer.strokeColor = polyline.speedColor
                renderer.lineWidth = 4.5
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let reuseId = "scrubDot"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            view.annotation = annotation
            let size: CGFloat = 12
            view.frame = CGRect(x: 0, y: 0, width: size, height: size)
            view.layer.cornerRadius = size / 2
            view.layer.masksToBounds = true
            // polarAmber #FBBF24
            view.backgroundColor = UIColor(red: 0xFB / 255.0, green: 0xBF / 255.0, blue: 0x24 / 255.0, alpha: 1)
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.white.cgColor
            view.centerOffset = .zero
            return view
        }

        // MARK: - Speed computation

        private func computeRawSpeeds(_ waypoints: [RoutePoint]) -> [Double] {
            (0..<waypoints.count - 1).map { i in
                let dt = waypoints[i + 1].elapsedMillis - waypoints[i].elapsedMillis
                guard dt > 0 else { return 0 }
                return haversine(waypoints[i], waypoints[i + 1]) / (Double(dt) / 1000.0)
            }
        }

        private func computeMidTimes(_ waypoints: [RoutePoint]) -> [Int] {
            (0..<waypoints.count - 1).map { i in
                (waypoints[i].elapsedMillis + waypoints[i + 1].elapsedMillis) / 2
            }
        }

        // 2.5-second trailing rolling mean to smooth GPS-jitter speed spikes
        private func rollingMean(speeds: [Double], midTimes: [Int], halfWindowMs: Int = 2500) -> [Double] {
            guard !speeds.isEmpty else { return [] }
            var result = [Double](repeating: 0, count: speeds.count)
            var windowSum = 0.0
            var lo = 0

            for hi in speeds.indices {
                windowSum += speeds[hi]
                // Evict entries that have fallen outside the left edge of the window
                while midTimes[hi] - midTimes[lo] > halfWindowMs {
                    windowSum -= speeds[lo]
                    lo += 1
                }
                result[hi] = windowSum / Double(hi - lo + 1)
            }
            return result
        }

        private func haversine(_ a: RoutePoint, _ b: RoutePoint) -> Double {
            let R = 6_371_000.0
            let lat1 = a.latitude  * .pi / 180
            let lat2 = b.latitude  * .pi / 180
            let dLat = (b.latitude  - a.latitude)  * .pi / 180
            let dLon = (b.longitude - a.longitude) * .pi / 180
            let s = sin(dLat / 2) * sin(dLat / 2)
                  + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
            return 2 * R * atan2(sqrt(s), sqrt(1 - s))
        }

        // Group consecutive waypoints in the same speed bin into a single polyline.
        // Uses 100 bins — contiguous segments with the same bin are merged, which
        // reduces overlay count to ~50–200 depending on how varied the speed is.
        private func buildSegments(
            waypoints: [RoutePoint],
            smoothedSpeeds: [Double],
            minSpeed: Double,
            maxSpeed: Double
        ) -> [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] {
            let range = maxSpeed - minSpeed

            func normalized(_ speed: Double) -> Double {
                range > 0 ? max(0, min(1, (speed - minSpeed) / range)) : 0.5
            }
            func bin(_ speed: Double) -> Int {
                min(99, Int(normalized(speed) * 100))
            }

            var result: [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] = []
            var current = [CLLocationCoordinate2D(latitude: waypoints[0].latitude,
                                                   longitude: waypoints[0].longitude)]
            var currentBin = bin(smoothedSpeeds[0])

            for i in 1..<waypoints.count {
                let coord = CLLocationCoordinate2D(latitude: waypoints[i].latitude,
                                                    longitude: waypoints[i].longitude)
                let speedIdx = min(i - 1, smoothedSpeeds.count - 1)
                let b = bin(smoothedSpeeds[speedIdx])

                if b != currentBin, current.count >= 2 {
                    result.append((current, Double(currentBin) / 99.0))
                    currentBin = b
                    // Overlap: new group starts from last point so no gaps
                    current = [current.last!, coord]
                } else {
                    current.append(coord)
                }
            }
            if current.count >= 2 {
                result.append((current, Double(currentBin) / 99.0))
            }
            return result
        }
    }
}
