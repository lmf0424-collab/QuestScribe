import SwiftUI
import SwiftData

@main
struct QuestScribeApp: App {
    @State private var paywallManager = PaywallManager()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(paywallManager)
                .task { await paywallManager.start() }
        }
        .modelContainer(for: [
            SessionNote.self,
            Quest.self,
            LootItem.self,
            NPC.self
        ])
    }
}
