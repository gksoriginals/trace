import Foundation

/// Memory-only Ask Trace: full local corpus + structured fields.
/// No bag-of-words keyword search over memory (PRD: local retrieval of structured facts).
enum MemoryAsk {
    static func answer(question: String, events: [MemoryEvent], scopeProjectId: String?) -> AskAnswer {
        let scoped: [MemoryEvent]
        if let scopeProjectId, !scopeProjectId.isEmpty {
            scoped = events.filter { $0.project?.id == scopeProjectId || scopeProjectId.isEmpty }
        } else {
            scoped = events
        }

        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let qLower = q.lowercased()
        let namedPath = extractPath(qLower)

        let selected: [MemoryEvent]
        if let namedPath {
            let hits = scoped.filter { locationCovers(namedPath, $0.what?.location ?? "") }
            if hits.isEmpty {
                return AskAnswer(
                    tier: "memory",
                    text: "No memory entry for this path or question.",
                    citations: [],
                    unknown: true,
                    usage: .unavailable
                )
            }
            selected = hits
        } else {
            selected = scoped
        }

        if selected.isEmpty {
            return AskAnswer(
                tier: "memory",
                text: "No memory entry for this path or question.",
                citations: [],
                unknown: true,
                usage: .unavailable
            )
        }

        let intent = classifyIntent(qLower)
        var parts: [String] = []
        var unknown = false
        let ids = Set(scoped.map(\.event_id))

        switch intent {
        case .safeRemove:
            let consumersUnknown = selected.contains { consumersUnknown($0) } || selected.isEmpty
            if consumersUnknown {
                unknown = true
                parts.append("Unknown whether it is safe to remove; consumers or lifecycle evidence is incomplete.")
            } else {
                parts.append("Memory does not authorize removal; it only records provenance.")
            }
            for event in selected {
                if let why = event.why, !why.isEmpty { parts.append(why) }
                if let loc = event.what?.location { parts.append("location:\(loc)") }
            }
        case .protected:
            for event in selected {
                if let why = event.why, !why.isEmpty { parts.append(why) }
            }
            if !parts.contains(where: { $0.lowercased().contains("never-delete") }) {
                parts.append("never-delete")
            }
        case .staleSize:
            for event in selected {
                if let why = event.why, !why.isEmpty { parts.append(why) }
                if whyLooksStale(event) { parts.append("Stale size note labelled stale.") }
            }
        case .consumers:
            for event in selected {
                if let why = event.why, !why.isEmpty { parts.append(why) }
                for c in event.project?.consumers ?? [] { parts.append(c) }
                if let loc = event.what?.location { parts.append("location:\(loc)") }
            }
        case .general:
            for event in selected {
                if let why = event.why, !why.isEmpty { parts.append(why) }
                if let loc = event.what?.location { parts.append("location:\(loc)") }
                if let kind = event.what?.kind { parts.append(kind) }
            }
        }

        let whys = selected.compactMap(\.why)
        if whys.contains(where: { $0.lowercased().contains("one consumer") })
            && whys.contains(where: { $0.lowercased().contains("shared") || $0.lowercased().contains("multiple") }) {
            parts.append("Conflicting consumer notes are both present; neither is preferred.")
            unknown = true
        }

        var text = parts.joined(separator: " ")
        if unknown {
            text = text.replacingOccurrences(of: "safe to remove", with: "not verified as removable")
        }
        let citations = selected.map(\.event_id).filter { ids.contains($0) }

        return AskAnswer(
            tier: "memory",
            text: text,
            citations: Array(Set(citations)),
            unknown: unknown,
            usage: .unavailable
        )
    }

    private enum Intent { case safeRemove, protected, staleSize, consumers, general }

    private static func classifyIntent(_ q: String) -> Intent {
        if q.contains("safe to remove") || ((q.contains("remove") || q.contains("delete")) && !q.contains("why")) {
            if q.contains(".env") || q.contains("secret") || q.contains("credential") { return .protected }
            return .safeRemove
        }
        if q.contains(".env") && (q.contains("delete") || q.contains("remove") || q.contains("can i")) {
            return .protected
        }
        if q.contains("how large") || q.contains("size") || q.contains("bytes") { return .staleSize }
        if q.contains("who uses") || q.contains("who share") || q.contains("shares") || q.contains("shared")
            || q.contains("node_modules") || q.contains("package-lock") {
            return .consumers
        }
        return .general
    }

    private static func consumersUnknown(_ event: MemoryEvent) -> Bool {
        let consumers = event.project?.consumers ?? []
        let joined = consumers.joined(separator: " ").lowercased()
        let why = (event.why ?? "").lowercased()
        return joined.contains("unknown") || why.contains("unknown consumer") || consumers.isEmpty
    }

    private static func whyLooksStale(_ event: MemoryEvent) -> Bool {
        (event.why ?? "").lowercased().contains("stale") || event.claim == "inferred"
    }

    private static func extractPath(_ question: String) -> String? {
        let pattern = #"([a-z0-9_.-]+(?:/[a-z0-9_.-]+)+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(question.startIndex..<question.endIndex, in: question)
        guard let match = regex.firstMatch(in: question, range: range),
              let swiftRange = Range(match.range(at: 1), in: question) else { return nil }
        return String(question[swiftRange])
    }

    private static func locationCovers(_ named: String, _ location: String) -> Bool {
        guard !location.isEmpty else { return false }
        let loc = location.lowercased().replacingOccurrences(of: "\\", with: "/")
        let n = named.lowercased().replacingOccurrences(of: "\\", with: "/")
        return loc == n || loc.contains(n) || loc.hasSuffix("/" + n) || loc.hasSuffix(n)
    }
}
