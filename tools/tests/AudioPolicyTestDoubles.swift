// Recording engines for the actual app policy and package FeedbackPolicy.
// No audio hardware or AVFoundation behavior is simulated by these checks.
public struct SpeechConfiguration {
    let rate: Double
    let volume: Double
    let language: String
    let pitchMultiplier: Double
}

@MainActor
public final class RecordingAudio {
    var events: [String] = []
    var current: String?
    public init() {}
    public func speak(_ text: String) {
        events.append("speak:" + text)
        current = text
    }
    public func speak(_ text: String, configuration: SpeechConfiguration) { speak(text) }
    public func playClickSound() {}
    public func stopAll() {
        events.append("stop")
        current = nil
    }
}

@MainActor
public final class RecordingHaptics {
    public var isPlaying = false
    var patterns: [HapticPattern] = []
    var starts: Int { patterns.count }
    var rejectBursts = false
    public init() {}
    public func start(pattern: HapticPattern) {
        patterns.append(pattern)
        switch pattern.mode {
        case .transient: break // A one-shot does not occupy the looping player.
        case .burst: isPlaying = !rejectBursts
        default: isPlaying = true
        }
    }
    public func stopAll() { isPlaying = false }
    public func playSingleTap() {}
}

public typealias SpatialAudioEngine = RecordingAudio
public typealias AVSpatialAudioEngine = RecordingAudio
public typealias HapticEngine = RecordingHaptics
public typealias CoreHapticsEngine = RecordingHaptics

@MainActor
final class ToneGenerator {
    var currentFrequency: Double?
    var starts = 0
    var counts: [Int] = []
    func playRepeatingTone(frequency: Double, duration: Double, interval: Double, count: Int) {
        currentFrequency = frequency
        starts += 1
        counts.append(count)
    }
    func stop() { currentFrequency = nil }
}
