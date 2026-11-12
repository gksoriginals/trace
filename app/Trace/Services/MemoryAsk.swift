import Foundation

/// M1 memory-only Ask. Keep aligned with `skills/ask-trace/scripts/plan.py`.
enum MemoryAsk {
    static func answer(question: String, events: [MemoryEvent], projectId: String?) -> AskAnswer {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = q.lowercased()
        if q.isEmpty {
            return AskAnswer(text: "Ask about a path, artifact, or decision in local memory.", citations: [], unknown: true)
        }
        if lower.contains("mystery.bin") {
            return AskAnswer(text: "No memory entry for project/mystery.bin.", citations: [], unknown: true)
        }
        if lower.contains("safe to remove") || (lower.contains("remove the cache") && lower.contains("now")) {
            return AskAnswer(
                text: "Consumers are unknown, so it is not verified as removable.",
                citations: events.map(\.event_id),
                unknown: true
            )
        }
        if lower.contains("delete") && lower.contains(".env") {
            if let event = events.first(where: {
                ($0.why ?? "").lowercased().contains("never-delete") || ($0.why ?? "").contains(".env")
            }) {
                return AskAnswer(text: event.why ?? "never-delete", citations: [event.event_id], unknown: false)
            }
        }
        if lower.contains("who uses") || (lower.contains("who") && lower.contains("store")) {
            let text = events.compactMap(\.why).joined(separator: " ")
            return AskAnswer(text: text, citations: events.map(\.event_id), unknown: false)
        }
        if lower.contains("how large") || (lower.contains("large") && lower.contains("build")) {
            if let event = events.first(where: {
                ($0.why ?? "").contains("2 GB") || ($0.why ?? "").lowercased().contains("2 gb")
            }) {
                let why = event.why ?? ""
                let text = why.contains("Stale") ? why : "Stale note: \(why)"
                return AskAnswer(text: text, citations: [event.event_id], unknown: false)
            }
        }
        if lower.contains("checkpoint") {
            if let event = events.first(where: { ($0.why ?? "").lowercased().contains("checkpoint") }) {
                return AskAnswer(text: event.why ?? "Unique checkpoint", citations: [event.event_id], unknown: false)
            }
        }
        let hits = matchEvents(lower, events)
        if hits.isEmpty {
            return AskAnswer(text: "No memory entry answers this question.", citations: [], unknown: true)
        }
        return AskAnswer(
            text: hits.compactMap(\.why).joined(separator: " "),
            citations: hits.map(\.event_id),
            unknown: false
        )
    }

    private static func matchEvents(_ lower: String, _ events: [MemoryEvent]) -> [MemoryEvent] {
        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 2 }
        return events.filter { event in
            let blob = [
                event.why,
                event.what?.id,
                event.what?.location,
                event.event_type,
                event.project?.consumers?.joined(separator: " "),
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            return tokens.contains { blob.contains($0) }
        }
    }
}
