import SwiftUI
import SwiftData

@main
struct QuestScribeApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(for: [
            SessionNote.self,
            Quest.self,
            LootItem.self,
            NPC.self
        ])
    }
}
