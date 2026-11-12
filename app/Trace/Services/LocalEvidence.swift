import Foundation

/// Reads skill-owned local stores. Never starts a model call.
enum LocalEvidence {
    static func loadIndex(at url: URL = TracePaths.indexURL) -> ProjectIndexFile {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ProjectIndexFile.self, from: data) else {
            return ProjectIndexFile(schema_version: 1, projects: [])
        }
        return file
    }

    static func loadMemory(at path: String) -> [MemoryEvent] {
        let url = URL(fileURLWithPath: path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var events: [MemoryEvent] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            if let event = try? JSONDecoder().decode(MemoryEvent.self, from: data) {
                events.append(event)
            }
        }
        return events
    }

    static func queueURL(nearMemoryLog path: String) -> URL {
        URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .appendingPathComponent("decide-later.json")
    }

    static func loadQueue(nearMemoryLog path: String) -> [DecideLaterItem] {
        let url = queueURL(nearMemoryLog: path)
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DecideLaterFile.self, from: data) else {
            return []
        }
        return file.items
    }

    static func mergeStatus(_ item: DecideLaterItem, overrides: [String: String]) -> DecideLaterItem {
        guard let status = overrides[item.id] else { return item }
        var copy = item
        copy.status = status
        return copy
    }
}
