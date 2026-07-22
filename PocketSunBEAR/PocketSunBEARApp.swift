import SwiftData
import SwiftUI

@main
struct PocketSunBEARApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(for: [ResearchSession.self, ResearchItem.self])
    }
}
