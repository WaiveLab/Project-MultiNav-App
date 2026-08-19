import SwiftUI

struct MapSwitcherView: View {
    
    @EnvironmentObject var session: StudySession
    
    var body: some View {
        List {
            Section("Select Overview") {
                ForEach(StudySession.overviewMaps, id: \.self) { mapName in
                    Button {
                        session.selectOverviewMap(mapName)
                    } label: {
                        HStack {
                            Text(displayName(for: mapName))
                            
                            Spacer()
                            
                            if session.currentMapName == mapName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func displayName(for mapName: String) -> String {
        mapName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "map\\d+ ",
                with: "",
                options: .regularExpression
            )
            .capitalized
    }
}
