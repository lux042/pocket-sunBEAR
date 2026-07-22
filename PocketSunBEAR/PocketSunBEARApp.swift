import SwiftData
import SwiftUI

@main
struct PocketSunBEARApp: App {
    var body: some Scene {
        WindowGroup { ContentView().preferredColorScheme(.dark) }
            .modelContainer(for: [LibraryCollection.self, ResearchSession.self, ResearchItem.self])
    }
}
