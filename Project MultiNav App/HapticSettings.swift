///deticated .swift file to store the default haptic settings

import SwiftUI
import Combine
import TactileMapCore
import TactileMapFeedback
import TactileMapLogging
import TactileMapView


@MainActor
class HapticSettings: ObservableObject {
    
    static let shared = HapticSettings()
    
    @Published var patterns = ParameterSet.defaultHaptics.mapValues { $0.hapticPattern }
}
