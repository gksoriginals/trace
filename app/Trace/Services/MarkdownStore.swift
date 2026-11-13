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
        let (meta, body) = loadFrontmatter(text)
        if let itemsJSON = meta["projects"], let data = itemsJSON.data(using: .utf8),
           let projects = try? JSONDecoder().decode([ProjectIndexRow].self, from: data) {
            let version = Int(meta["schema_version"] ?? "1") ?? 1
            return ProjectIndexFile(schema_version: version, projects: projects)
        }
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

    /// App-written Home insight card body (skills may replace later).
    static func writeInsights(body: String, at url: URL) throws {
        let text = [
            "---",
            "schema_version: 1",
            "---",
            "",
            body.trimmingCharacters(in: .whitespacesAndNewlines),
            "",
        ].joined(separator: "\n")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Bootstrap / update `~/.trace/index.md` (skills own ongoing updates; Setup seeds on first run).
    static func writeIndex(_ file: ProjectIndexFile, at url: URL) throws {
        let pretty = JSONEncoder()
        pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
        let projectsJSON = String(data: try pretty.encode(file.projects), encoding: .utf8) ?? "[]"
        let compactJSON = String(data: try JSONEncoder().encode(file.projects), encoding: .utf8) ?? "[]"
        let lines = [
            "---",
            "schema_version: \(file.schema_version)",
            "projects: \(compactJSON)",
            "---",
            "",
            "Trace project index. Skills maintain this file. The app reads it; Home does not call a model to open.",
            "",
            "```json",
            projectsJSON,
            "```",
            "",
        ]
        let md = lines.joined(separator: "\n")
        let target = url.pathExtension == "json" ? url.deletingPathExtension().appendingPathExtension("md") : url
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try md.write(to: target, atomically: true, encoding: .utf8)
    }

    /// Write product markdown and the JSON sibling (matches `skills/shared/queue_md.write_both`).
    static func writeDecideLater(items: [DecideLaterItem], baseDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let itemsData = try encoder.encode(items)
        let itemsJSON = String(data: itemsData, encoding: .utf8) ?? "[]"

        var bodyLines = ["# Decide later", ""]
        for item in items {
            bodyLines.append("## \(item.id) (\(item.status ?? "open"))")
            bodyLines.append("- action: \(item.action ?? "")")
            bodyLines.append("- why: \(item.why_doubtful ?? "")")
            bodyLines.append("- would resolve: \(item.would_resolve ?? "")")
            bodyLines.append("")
        }
        var mdLines = [
            "---",
            "schema_version: 1",
            "items: \(itemsJSON)",
            "---",
            "",
        ]
        mdLines.append(contentsOf: bodyLines)
        let md = mdLines.joined(separator: "\n")
        let mdURL = baseDirectory.appendingPathComponent("decide-later.md")
        let jsonURL = baseDirectory.appendingPathComponent("decide-later.json")
        try md.write(to: mdURL, atomically: true, encoding: .utf8)
        let payload = DecideLaterFile(items: items)
        try encoder.encode(payload).write(to: jsonURL, options: .atomic)
    }
}
