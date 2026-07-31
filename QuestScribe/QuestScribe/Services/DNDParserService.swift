import Foundation
import SwiftData

// MARK: - Decodable DTOs (mirror the JSON Schema)

struct ParsedPrepNotes: Codable {
    var quests: [ParsedQuest] = []
    var loot: [ParsedLootItem] = []
    var npcs: [ParsedNPC] = []
}

struct ParsedQuest: Codable {
    var title: String
    var details: String
    var status: String
    var relatedNPCNames: [String] = []
}

struct ParsedLootItem: Codable {
    var name: String
    var quantity: Int
    var isMagical: Bool
    var valueOrRarity: String
}

struct ParsedNPC: Codable {
    var name: String
    var roleOrLocation: String
    var disposition: String
}

// MARK: - Errors

enum ParserError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case http(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key found. Add one in Settings before scanning."
        case .invalidResponse:
            return "The parser returned an unexpected response."
        case .http(let statusCode, let message):
            return "OpenAI request failed (HTTP \(statusCode)): \(message)"
        case .decodingFailed:
            return "Could not read the structured data returned by the parser."
        }
    }
}

// MARK: - Service

/// Calls the OpenAI Chat Completions API with a JSON Schema to turn raw OCR
/// text into structured Quests / Loot / NPCs, then persists them into SwiftData.
struct DNDParserService {

    private let session: URLSession
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Parsing

    /// Sends `rawText` to the model and returns the structured result.
    func parse(rawText: String, apiKey: String) async throws -> ParsedPrepNotes {
        guard !apiKey.isEmpty else { throw ParserError.missingAPIKey }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": rawText]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "parsed_prep_notes",
                    "strict": true,
                    "schema": Self.jsonSchema
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ParserError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error?.message ?? "unknown error"
            throw ParserError.http(statusCode: http.statusCode, message: message)
        }

        guard let completion = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              let content = completion.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw ParserError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(ParsedPrepNotes.self, from: contentData)
        } catch {
            throw ParserError.decodingFailed
        }
    }

    // MARK: - Persistence

    /// Maps the parsed DTOs into SwiftData models and saves them into `context`.
    func persist(_ parsed: ParsedPrepNotes, rawText: String, into context: ModelContext) throws {
        let title = rawText
            .split(separator: "\n")
            .first
            .map { String($0.prefix(60)) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Scanned Notes"

        let note = SessionNote(rawText: rawText, title: title)
        context.insert(note)

        var npcByName: [String: NPC] = [:]
        for parsedNPC in parsed.npcs {
            let npc = NPC(
                name: parsedNPC.name.trimmed,
                roleOrLocation: parsedNPC.roleOrLocation.trimmed,
                disposition: parsedNPC.disposition.trimmed
            )
            npc.sessionNote = note
            context.insert(npc)
            note.npcs.append(npc)
            npcByName[npcKey(parsedNPC.name)] = npc
        }

        for parsedQuest in parsed.quests {
            let quest = Quest(
                title: parsedQuest.title.trimmed,
                details: parsedQuest.details.trimmed,
                status: QuestStatus(rawValue: parsedQuest.status.lowercased()) ?? .active
            )
            quest.sessionNote = note
            for name in parsedQuest.relatedNPCNames where !name.isEmpty {
                if let npc = npcByName[npcKey(name)] {
                    quest.relatedNPCs.append(npc)
                }
            }
            context.insert(quest)
            note.quests.append(quest)
        }

        for parsedItem in parsed.loot {
            let item = LootItem(
                name: parsedItem.name.trimmed,
                quantity: max(1, parsedItem.quantity),
                isMagical: parsedItem.isMagical,
                valueOrRarity: parsedItem.valueOrRarity.trimmed
            )
            item.sessionNote = note
            context.insert(item)
            note.loot.append(item)
        }

        try context.save()
    }

    private func npcKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Prompt & Schema

    private static var systemPrompt: String {
        """
        You are an expert Dungeons & Dragons Dungeon Master's assistant. You receive raw OCR text \
        extracted from handwritten session preparation notes. The text contains typos, OCR errors, \
        fragmented sentences, and casual abbreviations.

        Parse the notes into structured game data:
        - Quests: tasks, plot hooks, missions, or goals the party is pursuing.
        - Loot: items the party found or will find (treasure, gear, magical items).
        - NPCs: characters mentioned, including merchants, allies, villains, and monsters that have a name or notable role.

        Rules:
        - Correct obvious OCR typos and abbreviations using D&D context.
        - If a category is absent, return an empty array for it. Do not invent content that is not in the text.
        - Set quest status to "completed" only when the wording clearly indicates it (e.g. "returned", "done", "finished", "resolved"); otherwise "active".
        - For loot, set quantity to the mentioned count or 1 if unspecified. Set isMagical to true only for clearly magical items.
        - For NPCs, put a short role, faction, or location in roleOrLocation and a one-word disposition (e.g. "friendly", "hostile", "neutral", "unknown") in disposition.
        - Return ONLY valid JSON matching the provided schema.
        """
    }

    private static var jsonSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "quests": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "details": ["type": "string"],
                            "status": ["type": "string", "enum": ["active", "completed"]],
                            "relatedNPCNames": ["type": "array", "items": ["type": "string"]]
                        ],
                        "required": ["title", "details", "status", "relatedNPCNames"],
                        "additionalProperties": false
                    ]
                ],
                "loot": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "quantity": ["type": "integer"],
                            "isMagical": ["type": "boolean"],
                            "valueOrRarity": ["type": "string"]
                        ],
                        "required": ["name", "quantity", "isMagical", "valueOrRarity"],
                        "additionalProperties": false
                    ]
                ],
                "npcs": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "roleOrLocation": ["type": "string"],
                            "disposition": ["type": "string"]
                        ],
                        "required": ["name", "roleOrLocation", "disposition"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["quests", "loot", "npcs"],
            "additionalProperties": false
        ]
    }
}

// MARK: - Decoding helpers

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct APIErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String?
    }
    let error: ErrorDetail?
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
