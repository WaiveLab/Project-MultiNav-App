import Foundation

/// Spoken labels only. Resource lookup, target measurements and geometry retain
/// the original map names and identifiers.
enum StudyMapSpeech {
    static func label(type: String, name: String) -> String {
        switch type {
        case "start":
            if name.hasPrefix("Route enters from ") {
                return "Start of route from " + name.dropFirst("Route enters from ".count)
            }
            return "Start of route"
        case "end":
            if name.hasPrefix("Route continues on ") {
                return "End of route on " + name.dropFirst("Route continues on ".count)
            }
            return "End of route"
        case "onRoute", "onRouteIntersection", "onRouteSidewalk", "onRouteCrosswalk":
            return name + ", route"
        case "turn":
            return "Turn"
        default:
            return name
        }
    }
}
