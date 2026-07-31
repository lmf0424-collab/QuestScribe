import SwiftData
import SwiftUI

// MARK: - HUD

/// Main mid-game HUD: tabbed sections for Quests, Loot, NPCs, and Settings,
/// with a floating "Scan Notes" action.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PaywallManager.self) private var paywallManager

    @State private var coordinator = ScanCoordinator()
    @State private var selectedTab = 0
    @State private var showScanner = false
    @State private var showPaywall = false
    @State private var pendingImage: UIImage?
    @State private var showAPIKeyAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QuestsListView()
            }
            .toolbar { scanToolbarItem }
            .tabItem { Label("Quests", systemImage: "flag.fill") }
            .tag(0)

            NavigationStack {
                LootListView()
            }
            .toolbar { scanToolbarItem }
            .tabItem { Label("Loot", systemImage: "gift.fill") }
            .tag(1)

            NavigationStack {
                NPCListView()
            }
            .toolbar { scanToolbarItem }
            .tabItem { Label("NPCs", systemImage: "person.2.fill") }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .toolbar { scanToolbarItem }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(3)
        }
        .overlay {
            if coordinator.isProcessing {
                ProcessingOverlayView(stage: coordinator.stage)
            }
        }
        .sheet(isPresented: $showScanner) {
            CameraScannerView { image in
                pendingImage = image
                showScanner = false
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: pendingImage) { _, image in
            guard let image else { return }
            pendingImage = nil
            Task { await coordinator.process(image: image, context: modelContext) }
        }
        .alert("API Key Required", isPresented: $showAPIKeyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") { selectedTab = 3 }
        } message: {
            Text("Add your OpenAI API key in Settings before scanning notes.")
        }
        .alert(
            "Scan Failed",
            isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(coordinator.errorMessage ?? "Unknown error")
        }
    }

    private var scanToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: handleScanTap) {
                Label("Scan Notes", systemImage: "camera.viewfinder")
            }
        }
    }

    private func handleScanTap() {
        guard paywallManager.isPro else {
            showPaywall = true
            return
        }
        if (KeychainHelper.loadAPIKey() ?? "").isEmpty {
            showAPIKeyAlert = true
        } else {
            showScanner = true
        }
    }
}

// MARK: - Quests

private struct QuestsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.title) private var quests: [Quest]

    private var activeQuests: [Quest] {
        quests.filter { $0.status == .active }
    }

    private var completedQuests: [Quest] {
        quests.filter { $0.status == .completed }
    }

    var body: some View {
        Group {
            if quests.isEmpty {
                ContentUnavailableView {
                    Label("No Quests", systemImage: "flag.fill")
                } description: {
                    Text("Tap \"Scan Notes\" to import your session prep.")
                }
            } else {
                List {
                    Section("Active") {
                        ForEach(activeQuests) { quest in
                            questRow(quest)
                        }
                    }
                    if !completedQuests.isEmpty {
                        Section("Completed") {
                            ForEach(completedQuests) { quest in
                                questRow(quest)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Quests")
    }

    private func questRow(_ quest: Quest) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: quest.status == .completed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(quest.status == .completed ? Color.green : Color.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.headline)
                    .strikethrough(quest.status == .completed)

                if !quest.details.isEmpty {
                    Text(quest.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let date = quest.sessionNote?.date {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !quest.relatedNPCs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quest.relatedNPCs) { npc in
                                Text(npc.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle(quest) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(quest)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                toggle(quest)
            } label: {
                Label(
                    quest.status == .completed ? "Reopen" : "Complete",
                    systemImage: quest.status == .completed ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(quest.status == .completed ? .gray : .green)
        }
    }

    private func toggle(_ quest: Quest) {
        quest.status = quest.status == .active ? .completed : .active
    }
}

// MARK: - Loot

private struct LootListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LootItem.name) private var loot: [LootItem]

    var body: some View {
        Group {
            if loot.isEmpty {
                ContentUnavailableView {
                    Label("No Loot", systemImage: "gift.fill")
                } description: {
                    Text("Scanned treasures and rewards will appear here.")
                }
            } else {
                List {
                    Section("Loot & Rewards") {
                        ForEach(loot) { item in
                            lootRow(item)
                        }
                    }
                }
            }
        }
        .navigationTitle("Loot")
    }

    private func lootRow(_ item: LootItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isMagical ? "wand.and.stars" : "circle")
                .font(.title3)
                .foregroundStyle(item.isMagical ? Color.purple : Color.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.headline)
                    if item.quantity > 1 {
                        Text("x\(item.quantity)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                if !item.valueOrRarity.isEmpty {
                    Text(item.valueOrRarity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - NPCs

private struct NPCListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NPC.name) private var npcs: [NPC]

    var body: some View {
        Group {
            if npcs.isEmpty {
                ContentUnavailableView {
                    Label("No NPCs", systemImage: "person.2.fill")
                } description: {
                    Text("Scanned characters will appear here.")
                }
            } else {
                List {
                    Section("NPCs") {
                        ForEach(npcs) { npc in
                            npcRow(npc)
                        }
                    }
                }
            }
        }
        .navigationTitle("NPCs")
    }

    private func npcRow(_ npc: NPC) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(npc.name)
                    .font(.headline)
                if !npc.roleOrLocation.isEmpty {
                    Text(npc.roleOrLocation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)

            if !npc.disposition.isEmpty {
                Text(npc.disposition)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(dispositionColor(npc.disposition))
                    .background(dispositionColor(npc.disposition).opacity(0.15), in: Capsule())
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(npc)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func dispositionColor(_ disposition: String) -> Color {
        let text = disposition.lowercased()
        if text.contains("hostil") || text.contains("enemy") || text.contains("danger") {
            return .red
        }
        if text.contains("friend") || text.contains("ally") || text.contains("kind") {
            return .green
        }
        if text.contains("neutral") || text.contains("unknown") {
            return .secondary
        }
        return Color.accentColor
    }
}
