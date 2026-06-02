import MapKit

enum MMLTileOverlay {
    static func urlTemplate(apiKey: String) -> String {
        "https://avoin-karttakuva.maanmittauslaitos.fi/avoinapi/tiles/wmts/1.0.0" +
        "/maastokartta/default/WGS84_Pseudo-Mercator/{z}/{y}/{x}.png?api-key=\(apiKey)"
    }

    static func make(apiKey: String) -> MKTileOverlay {
        let overlay = MKTileOverlay(urlTemplate: urlTemplate(apiKey: apiKey))
        overlay.canReplaceMapContent = true
        overlay.minimumZ = 0
        overlay.maximumZ = 15
        return overlay
    }
}
