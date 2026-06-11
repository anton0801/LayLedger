//
//  Persistence.swift
//  LayLedger
//
//  Single-file JSON persistence of the whole app state in the Documents directory.
//

import Foundation

struct PersistedState: Codable {
    var flocks: [Flock] = []
    var breeds: [Breed] = []
    var eggEntries: [EggEntry] = []
    var records: [LedgerRecord] = []
    var tasks: [TaskItem] = []
    var photos: [PhotoItem] = []
    var events: [CalendarEvent] = []
    var categories: [String] = []
    var dismissedRecKeys: [String] = []
    var savedRecKeys: [String] = []
    var hasSeeded: Bool = false
}

final class PersistenceService {
    private let fileName = "layledger_state.json"

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    func load() -> PersistedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedState.self, from: data)
    }

    func save(_ state: PersistedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Returns a temporary URL with the exported JSON for sharing.
    func exportFileURL(_ state: PersistedState) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(state) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LayLedger-Backup.json")
        try? data.write(to: url, options: .atomic)
        return url
    }
}
