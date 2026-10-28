import Foundation
import TactileMapCore

/// Fits the occupied coordinate space, leaving physical stroke/marker sizes to
/// the existing renderer. All layers share one transform for drawing and hits.
enum StudyMapLayout {
    /// Uses the existing renderer's zebra crossings as decoration only. Original
    /// on/off-route elements keep their IDs, geometry, hit priority and feedback.
    /// Call after fitting so the additional layer cannot change the map transform.
    static func withCrosswalkStripes(_ layers: [TactileMapLayer]) -> [TactileMapLayer] {
        guard let first = layers.first else { return layers }
        var stripes: [MapElement] = []
        var seen: Set<TactileGeometry> = []
        var markers: [MapElement] = []
        for layer in layers {
            for feature in layer.document.features {
                let type = feature.elementType.rawValue
                if ["onRouteCrosswalk", "offRouteCrosswalk"].contains(type),
                   case .lineString(let points) = feature.geometry, points.count >= 2 {
                    guard !seen.contains(feature.geometry) else { continue }
                    seen.insert(feature.geometry)
                    seen.insert(.lineString(Array(points.reversed())))
                    stripes.append(MapElement(
                        id: "\(layer.id):stripe:\(feature.id)", elementType: .crosswalk,
                        geometry: feature.geometry, properties: feature.properties
                    ))
                } else if ["start", "end", "turn"].contains(type),
                          case .point = feature.geometry {
                    // Redraw these above the stripes so crossing ends never obscure markers.
                    markers.append(MapElement(
                        id: "\(layer.id):marker:\(feature.id)", elementType: feature.elementType,
                        geometry: feature.geometry, properties: feature.properties
                    ))
                }
            }
        }
        guard !stripes.isEmpty else { return layers }
        let decoration = TactileMapDocument(
            version: first.document.version, bounds: first.document.bounds,
            features: stripes + markers, metadata: first.document.metadata
        )
        return layers + [TactileMapLayer(
            id: "crosswalk-decoration", document: decoration, isInteractable: false
        )]
    }

    static func fittedLayers(_ layers: [TactileMapLayer]) -> [TactileMapLayer] {
        let points = layers.flatMap { $0.document.features }.flatMap { coordinates($0.geometry) }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(),
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              maxX > minX, maxY > minY else { return layers }
        let bounds = TactileMapBounds(width: maxX - minX, height: maxY - minY)
        func shift(_ point: TactileCoordinate) -> TactileCoordinate {
            TactileCoordinate(x: point.x - minX, y: point.y - minY)
        }
        return layers.map { layer in
            let features = layer.document.features.map { feature in
                let geometry: TactileGeometry
                switch feature.geometry {
                case .point(let point): geometry = .point(shift(point))
                case .lineString(let points): geometry = .lineString(points.map(shift))
                case .polygon(let points): geometry = .polygon(points.map(shift))
                }
                return MapElement(id: feature.id, elementType: feature.elementType,
                                  geometry: geometry, properties: feature.properties)
            }
            return TactileMapLayer(id: layer.id, document: TactileMapDocument(
                version: layer.document.version, bounds: bounds, features: features,
                metadata: layer.document.metadata
            ), isInteractable: layer.isInteractable)
        }
    }

    private static func coordinates(_ geometry: TactileGeometry) -> [TactileCoordinate] {
        switch geometry {
        case .point(let point): return [point]
        case .lineString(let points), .polygon(let points): return points
        }
    }
}
