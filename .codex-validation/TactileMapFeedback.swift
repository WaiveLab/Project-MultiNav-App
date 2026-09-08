public struct HapticPattern: Equatable {
    public enum HapticMode: Equatable {
        case burst(pulseCount: Int, onDuration: Double, offDuration: Double)
    }

    public let intensity: Float
    public let sharpness: Float
    public let mode: HapticMode

    public init(intensity: Float, sharpness: Float, mode: HapticMode) {
        self.intensity = intensity
        self.sharpness = sharpness
        self.mode = mode
    }
}
