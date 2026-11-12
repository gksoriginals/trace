import Foundation

/// Minimal frontmatter reader for Home / Ask (ADR-0007).
enum MarkdownStore {
    static func loadFrontmatter(_ text: String) -> (meta: [String: String], body: String) {
        guard text.hasPrefix("---") else { return ([:], text) }
        let parts = text.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return ([:], text) }
        var meta: [String: String] = [:]
        for line in parts[1].split(separator: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            guard let idx = s.firstIndex(of: ":") else { continue }
            let key = String(s[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(s[s.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            meta[key] = value
        }
        return (meta, String(parts[2]))
    }

    static func parseIndex(at url: URL) throws -> ProjectIndexFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ProjectIndexFile(schema_version: 1, projects: [])
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            return try JSONDecoder().decode(ProjectIndexFile.self, from: Data(text.utf8))
        }
        let (_, body) = loadFrontmatter(text)
        if let start = body.range(of: "["),
           let end = body.range(of: "]", options: .backwards) {
            let json = String(body[start.lowerBound...end.upperBound])
            let projects = try JSONDecoder().decode([ProjectIndexRow].self, from: Data(json.utf8))
            return ProjectIndexFile(schema_version: 1, projects: projects)
        }
        return ProjectIndexFile(schema_version: 1, projects: [])
    }

    static func parseMemoryDir(at url: URL) -> [MemoryEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
        var events: [MemoryEvent] = []
        for file in files where file.pathExtension == "md" {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let (meta, body) = loadFrontmatter(text)
            guard let eventId = meta["event_id"], !eventId.isEmpty else { continue }
            let correction = meta["correction_of"]
            events.append(MemoryEvent(
                schema_version: Int(meta["schema_version"] ?? "1"),
                event_id: eventId,
                event_type: meta["event_type"],
                what: .init(
                    id: meta["what.id"],
                    kind: meta["what.kind"],
                    location: meta["what.location"],
                    bytes: meta["what.bytes"].flatMap { Int($0) },
                    completeness: meta["what.completeness"]
                ),
                why: body.trimmingCharacters(in: .whitespacesAndNewlines),
                claim: meta["claim"],
                agent: .init(harness: meta["agent.harness"], session_id: meta["agent.session_id"]),
                project: .init(id: meta["project.id"], consumers: nil),
                created: .init(at: meta["created.at"], source: meta["created.source"]),
                can_go_when: meta["can_go_when"],
                evidence_ids: nil,
                correction_of: (correction == nil || correction == "null") ? nil : correction,
                attribution: nil
            ))
        }
        return events.sorted { $0.event_id < $1.event_id }
    }

    static func parseDecideLater(at url: URL) -> [DecideLaterItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        if url.pathExtension == "json" || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            if let file = try? JSONDecoder().decode(DecideLaterFile.self, from: Data(text.utf8)) {
                return file.items
            }
            return (try? JSONDecoder().decode([DecideLaterItem].self, from: Data(text.utf8))) ?? []
        }
        let (meta, _) = loadFrontmatter(text)
        if let itemsJSON = meta["items"], let data = itemsJSON.data(using: .utf8),
           let items = try? JSONDecoder().decode([DecideLaterItem].self, from: data) {
            return items
        }
        return []
    }

    static func insightsBody(at url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        let (_, body) = loadFrontmatter(text)
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
