import MapKit
import SwiftUI

// MARK: - SpeedTrackOverlay

final class SpeedTrackOverlay: NSObject, MKOverlay {
    struct Segment {
        let coords: [CLLocationCoordinate2D]
        let color: UIColor
        let normalizedSpeed: Double
    }

    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let segments: [Segment]

    init(segments: [Segment]) {
        self.segments = segments
        var rect = MKMapRect.null
        for seg in segments {
            for coord in seg.coords {
                let pt = MKMapPoint(coord)
                rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
            }
        }
        self.boundingMapRect = rect.isNull ? .world : rect
        self.coordinate = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
    }
}

// MARK: - SpeedTrackRenderer

final class SpeedTrackRenderer: MKOverlayRenderer {
    private let track: SpeedTrackOverlay

    init(_ overlay: SpeedTrackOverlay) {
        self.track = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let lineWidth = 3.5 / zoomScale

        context.setLineJoin(.round)

        // Glow pass — each segment in its own transparency layer, with a shadow
        // tinted to the segment's own speed color and scaled by speed. Fast
        // segments bloom large and bright; slow segments stay a tight, dim line.
        // Adjacent fast→slow boundaries let the hot bloom spill over the cool
        // line, so heat appears to radiate from the fast sections.
        for seg in track.segments {
            guard let path = makePath(seg.coords) else { continue }
            let blur  = GlowProfile.blurFactor(seg.normalizedSpeed) / zoomScale
            let alpha = GlowProfile.alpha(seg.normalizedSpeed)
            context.saveGState()
            context.setShadow(offset: .zero, blur: blur,
                              color: seg.color.withAlphaComponent(alpha).cgColor)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            context.setLineCap(.round)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(seg.color.cgColor)
            context.addPath(path)
            context.strokePath()
            context.endTransparencyLayer()
            context.restoreGState()
        }

        // Crisp line pass — butt caps so adjacent segments meet flush at their
        // shared coordinate with no round-cap overlap.
        context.setLineCap(.butt)
        context.setLineWidth(lineWidth)
        for seg in track.segments {
            guard let path = makePath(seg.coords) else { continue }
            context.setStrokeColor(seg.color.cgColor)
            context.addPath(path)
            context.strokePath()
        }

        // White filament — 1 pt center highlight, rides on top of the colored core.
        // Framed by ~1.25 pt of color on each side so it reads on any background.
        context.setLineCap(.butt)
        context.setLineWidth(1.0 / zoomScale)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
        for seg in track.segments {
            guard let path = makePath(seg.coords) else { continue }
            context.addPath(path)
            context.strokePath()
        }
    }

    private func makePath(_ coords: [CLLocationCoordinate2D]) -> CGPath? {
        guard coords.count >= 2 else { return nil }
        let path = CGMutablePath()
        for (i, coord) in coords.enumerated() {
            let pt = point(for: MKMapPoint(coord))
            if i == 0 { path.move(to: pt) }
            else       { path.addLine(to: pt) }
        }
        return path
    }
}

// MARK: - TrackMapView

struct TrackMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double
    @Binding var speedKmh: Double
    @Binding var recenterToken: Int

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false   // keep north-up
        mapView.isPitchEnabled = false
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        context.coordinator.buildOverlays(on: mapView, routePoints: routePoints)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.rebuildIfNeeded(on: mapView, routePoints: routePoints)
        context.coordinator.moveScrubDot(on: mapView, routePoints: routePoints, fraction: scrubFraction)
        context.coordinator.recenterIfNeeded(on: mapView, token: recenterToken)
        let speeds = context.coordinator.filledSpeeds
        guard !speeds.isEmpty else { return }
        let idx = max(0, min(speeds.count - 1, Int(scrubFraction * Double(speeds.count - 1))))
        let rounded = (speeds[idx] * 10).rounded() / 10
        if abs(rounded - speedKmh) > 0.05 {
            DispatchQueue.main.async { speedKmh = rounded }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let scrubAnnotation = MKPointAnnotation()
        private var cachedRoutePoints: [RoutePoint] = []
        private(set) var filledSpeeds: [Double] = []
        private var routeRect: MKMapRect = .null
        private var lastRecenterToken = 0
        private var tileOverlay: MKTileOverlay?

        func buildOverlays(on mapView: MKMapView, routePoints: [RoutePoint]) {
            if !BuildConfig.mmlApiKey.isEmpty {
                let tile = MMLTileOverlay.make(apiKey: BuildConfig.mmlApiKey)
                tileOverlay = tile
                mapView.addOverlay(tile, level: .aboveLabels)
            }

            cachedRoutePoints = routePoints
            guard routePoints.count >= 2 else { return }

            filledSpeeds = SpeedInterpolator.fill(routePoints.map { $0.speedKmh })
            let normalize = SpeedNormalizer.make(from: filledSpeeds)

            // No recorded speed at all → flat amber (normalized 0.5).
            func bin(_ i: Int) -> Int {
                guard !filledSpeeds.isEmpty else { return 50 }
                return min(99, Int(normalize(filledSpeeds[i]) * 100))
            }

            var result: [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] = []
            var current = [CLLocationCoordinate2D(latitude: routePoints[0].latitude,
                                                   longitude: routePoints[0].longitude)]
            var currentBin = bin(0)

            for i in 1..<routePoints.count {
                let coord = CLLocationCoordinate2D(latitude: routePoints[i].latitude,
                                                    longitude: routePoints[i].longitude)
                let b = bin(i)
                if b != currentBin, current.count >= 2 {
                    result.append((current, Double(currentBin) / 99.0))
                    currentBin = b
                    current = [current.last!, coord]
                } else {
                    current.append(coord)
                }
            }
            if current.count >= 2 {
                result.append((current, Double(currentBin) / 99.0))
            }

            let segments = result.map {
                SpeedTrackOverlay.Segment(coords: $0.coords,
                                          color: SpeedColorRamp.color(for: $0.normalizedSpeed),
                                          normalizedSpeed: $0.normalizedSpeed)
            }
            mapView.addOverlay(SpeedTrackOverlay(segments: segments), level: .aboveLabels)

            var rect = MKMapRect.null
            for p in routePoints {
                let pt = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
                rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
            }
            let fitRect = rect
            routeRect = fitRect
            DispatchQueue.main.async {
                mapView.setVisibleMapRect(fitRect,
                    edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                    animated: false)
            }

            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: routePoints[0].latitude,
                longitude: routePoints[0].longitude)
            mapView.addAnnotation(scrubAnnotation)
        }

        func rebuildIfNeeded(on mapView: MKMapView, routePoints: [RoutePoint]) {
            guard cachedRoutePoints.isEmpty, routePoints.count >= 2 else { return }
            buildOverlays(on: mapView, routePoints: routePoints)
        }

        func moveScrubDot(on mapView: MKMapView, routePoints: [RoutePoint], fraction: Double) {
            guard !cachedRoutePoints.isEmpty else { return }
            let idx = min(cachedRoutePoints.count - 1,
                          max(0, Int(fraction * Double(cachedRoutePoints.count - 1))))
            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: cachedRoutePoints[idx].latitude,
                longitude: cachedRoutePoints[idx].longitude)
        }

        func recenterIfNeeded(on mapView: MKMapView, token: Int) {
            guard token != lastRecenterToken else { return }
            guard !routeRect.isNull else { return }   // don't consume the token until we can act
            lastRecenterToken = token
            mapView.setVisibleMapRect(routeRect,
                edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                animated: true)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            guard let track = overlay as? SpeedTrackOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            return SpeedTrackRenderer(track)
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
            view.backgroundColor = UIColor(red: 0xFB / 255.0, green: 0xBF / 255.0,
                                           blue: 0x24 / 255.0, alpha: 1)
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.white.cgColor
            view.centerOffset = .zero
            return view
        }

    }
}
