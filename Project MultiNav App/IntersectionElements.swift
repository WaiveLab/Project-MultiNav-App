//
//  IntersectionElements.swift
//  Project MultiNav App
//
//  Screen 2 (Intersection Exploration) element types + visual styling.
//
//  NOTE: These element definitions are PROVISIONAL pending Paul's confirmation
//  of the final Screen 2 element list. The four open questions are:
//    1. crosswalk — keep as its own element, or fold into the street crossing?
//    2. street — one element w/ two directional labels, or two elements?
//    3. median/island — placement?
//    4. aps — placement / count per intersection?
//  Update the rawValues + styles here once confirmed; everything else
//  (JSON, feedback, settings, MOBO) keys off these types.
//

import UIKit
import TactileMapCore
import TactileMapView

// MARK: - Custom element types for the Intersection Exploration view

extension TactileElementType {
    static let route        = TactileElementType(rawValue: "route")
    static let street       = TactileElementType(rawValue: "street")
    static let sidewalk     = TactileElementType(rawValue: "sidewalk")
    static let sidewalkBorder = TactileElementType(rawValue: "sidewalk_border")
    static let crosswalk    = TactileElementType(rawValue: "crosswalk")
    static let median       = TactileElementType(rawValue: "median")
    static let aps          = TactileElementType(rawValue: "aps")
    static let youAreHere   = TactileElementType(rawValue: "you_are_here")
    static let destination  = TactileElementType(rawValue: "destination")
    // `landmark` is built into the library and used for POIs.
}

// MARK: - Visual styling

/// Builds a `TactileMapViewConfiguration` styled to match the Screen 2 mockup.
///
/// All sizes are in millimeters and rendered at physically-consistent size on
/// every device via the library's PPI database. The mockup's "street is 3x the
/// sidewalk width" rule is encoded as 15mm street vs 5mm sidewalk.
enum IntersectionMapStyle {

    static func configuration() -> TactileMapViewConfiguration {
        var config = TactileMapViewConfiguration.default
        config.renderingMode = .canvas          // mockup-accurate junction rendering
        config.backgroundColor = .white

        config.typeStyles[.route] = ElementStyle(
            color: UIColor(red: 0.10, green: 0.71, blue: 0.91, alpha: 1.0),   // cyan
            sizeMM: 4.0
        )
        config.typeStyles[.street] = ElementStyle(
            color: UIColor(red: 0.07, green: 0.15, blue: 0.48, alpha: 1.0),   // dark blue
            sizeMM: 11.0                                                       // ~3x sidewalk
        )
        config.typeStyles[.sidewalkBorder] = ElementStyle(
            color: .black,
            sizeMM: 5.5                     // wider than sidewalk -> black outline around the gray
        )
        config.typeStyles[.sidewalk] = ElementStyle(
            color: UIColor(white: 0.73, alpha: 1.0),                          // gray
            sizeMM: 4.0
        )
        config.typeStyles[.crosswalk] = ElementStyle(
            color: .white,
            sizeMM: 1.2                     // thin stripes, widely spaced in JSON so gaps can't merge
        )
        config.typeStyles[.median] = ElementStyle(
            color: UIColor(red: 0.89, green: 0.20, blue: 0.17, alpha: 1.0),   // red
            sizeMM: 4.0,
            pointShape: .roundedRect(cornerRadius: 1.0)
        )
        config.typeStyles[.aps] = ElementStyle(
            color: UIColor(white: 0.17, alpha: 1.0),                          // near-black
            sizeMM: 4.0
        )
        config.typeStyles[.landmark] = ElementStyle(
            color: UIColor.systemPurple,
            sizeMM: 5.0,
            pointShape: .roundedRect(cornerRadius: 1.5),
            showAnchorDot: true
        )
        config.typeStyles[.youAreHere] = ElementStyle(
            color: UIColor(red: 1.0, green: 0.83, blue: 0.0, alpha: 1.0),     // yellow
            sizeMM: 6.5
        )
        config.typeStyles[.destination] = ElementStyle(
            color: UIColor(red: 1.0, green: 0.83, blue: 0.0, alpha: 1.0),     // yellow
            sizeMM: 6.5
        )

        return config
    }
}
