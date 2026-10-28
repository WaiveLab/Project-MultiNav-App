import Foundation

/// Used only when the session explicitly selects local testing. Remote
/// candidates and the serialized snapshot of tested parameters are unchanged.
enum PracticeHaptics {
    static var profiles: [HapticPat: BurstParameters] {
        let maximumIntensityTypes: Set<HapticPat> = [
            .start, .end, .onRoute, .onRouteIntersection, .offRouteIntersection,
            .onRouteSidewalk, .onRouteCrosswalk, .turn, .intersectionCenter,
        ]
        return ParameterSet.defaultHaptics.reduce(into: [:]) { result, entry in
            let (type, profile) = entry
            result[type] = BurstParameters(
                intensity: maximumIntensityTypes.contains(type) ? 1 : profile.intensity,
                sharpness: profile.sharpness,
                pulseCount: profile.pulseCount,
                onDuration: profile.onDuration,
                offDuration: profile.offDuration
            )
        }
    }
}
