import Foundation
import SwiftData

// MARK: - Enums

enum QuestStatus: String, Codable, CaseIterable {
    case active
    case completed

    var label: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Models

@Model
final class SessionNote {
    var id: UUID = UUID()
    var date: Date = Date()
    var rawText: String = ""
    var title: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Quest.sessionNote)
    var quests: [Quest] = []

    @Relationship(deleteRule: .cascade, inverse: \LootItem.sessionNote)
    var loot: [LootItem] = []

    @Relationship(deleteRule: .cascade, inverse: \NPC.sessionNote)
    var npcs: [NPC] = []

    init(rawText: String = "", title: String = "", date: Date = Date()) {
        self.rawText = rawText
        self.title = title
        self.date = date
    }
}

@Model
final class Quest {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var status: QuestStatus = QuestStatus.active
    var sessionNote: SessionNote?

    @Relationship(inverse: \NPC.relatedQuests)
    var relatedNPCs: [NPC] = []

    init(title: String = "", details: String = "", status: QuestStatus = .active) {
        self.title = title
        self.details = details
        self.status = status
    }
}

@Model
final class LootItem {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: Int = 1
    var isMagical: Bool = false
    var valueOrRarity: String = ""
    var sessionNote: SessionNote?

    init(name: String = "", quantity: Int = 1, isMagical: Bool = false, valueOrRarity: String = "") {
        self.name = name
        self.quantity = quantity
        self.isMagical = isMagical
        self.valueOrRarity = valueOrRarity
    }
}

@Model
final class NPC {
    var id: UUID = UUID()
    var name: String = ""
    var roleOrLocation: String = ""
    var disposition: String = ""
    var sessionNote: SessionNote?
    var relatedQuests: [Quest] = []

    init(name: String = "", roleOrLocation: String = "", disposition: String = "") {
        self.name = name
        self.roleOrLocation = roleOrLocation
        self.disposition = disposition
    }
}
