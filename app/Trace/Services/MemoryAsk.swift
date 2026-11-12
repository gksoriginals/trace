import Foundation

/// Memory-only Ask Trace retrieval. No hosted model call.
enum MemoryAsk {
    static func answer(question: String, events: [MemoryEvent], scopeProjectId: String?) -> AskAnswer {
        let q = question.lowercased()
        let scoped = events.filter { event in
            guard let scopeProjectId else { return true }
            return event.project?.id == scopeProjectId || scopeProjectId.isEmpty
        }
        let tokens = q.split { !$0.isLetter && !$0.isNumber && $0 != "/" && $0 != "." && $0 != "-" && $0 != "_" }
            .map(String.init)
            .filter { $0.count > 2 }

        var matched: [MemoryEvent] = []
        var facts: [String] = []
        for event in scoped {
            let blob = [
                event.why ?? "",
                event.what?.location ?? "",
                event.what?.kind ?? "",
                event.event_id,
                (event.project?.consumers ?? []).joined(separator: " "),
            ].joined(separator: " ").lowercased()
            let hit = tokens.contains { blob.contains($0) }
                || (event.what?.location).map { q.contains(($0 as NSString).lastPathComponent.lowercased()) } == true
            if hit {
                matched.append(event)
                if let why = event.why, !why.isEmpty { facts.append(why) }
                if let loc = event.what?.location { facts.append("location:\(loc)") }
            }
        }

        let ids = Set(scoped.map(\.event_id))
        var citations = matched.map(\.event_id).filter { ids.contains($0) }
        citations = Array(Set(citations))

        var unknown = matched.isEmpty
        var parts: [String] = []

        let asksRemoval = q.contains("safe to remove") || q.contains("delete") || q.contains("remove")
        if asksRemoval {
            let consumersUnknown = matched.isEmpty || matched.contains {
                ($0.project?.consumers ?? []).joined(separator: " ").lowercased().contains("unknown")
                    || ($0.why ?? "").lowercased().contains("unknown consumer")
            }
            if consumersUnknown {
                unknown = true
                parts.append("Unknown whether it is safe to remove; consumers or lifecycle evidence is incomplete.")
            } else {
                parts.append("Memory does not authorize removal; it only records provenance.")
            }
        }

        if matched.isEmpty {
            unknown = true
            parts.append("No matching memory events for this question.")
        } else {
            parts.append(contentsOf: facts.prefix(6))
        }

        let whys = matched.compactMap(\.why)
        if whys.contains(where: { $0.lowercased().contains("one consumer") })
            && whys.contains(where: { $0.lowercased().contains("shared") || $0.lowercased().contains("multiple") }) {
            parts.append("Conflicting consumer notes are both present; neither is preferred.")
            unknown = true
        }

        var text = parts.joined(separator: " ")
        if unknown {
            text = text.replacingOccurrences(of: "safe to remove", with: "not verified as removable")
        }

        return AskAnswer(
            tier: "memory",
            text: text,
            citations: citations,
            unknown: unknown,
            usage: UsageReport.unavailable
        )
    }
}
