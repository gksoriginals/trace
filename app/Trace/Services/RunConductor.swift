import Foundation

/// Builds action cards from memory + optional Reviewing notes; executes via TrashService.
@MainActor
final class RunConductor: ObservableObject {
    enum Stage: String {
        case reviewing, actions, execute, done
    }

    @Published var stage: Stage = .reviewing
    @Published var milestones: [String] = []
    @Published var cards: [ActionCard] = []
    @Published var results: [TrashService.Result] = []
    @Published var usage: UsageReport = .unavailable
    @Published var selectionId: String = UUID().uuidString

    func startReviewing(store: TraceStore, project: ProjectIndexRow, agent: AgentKind, supervisor: SessionSupervisor) async {
        stage = .reviewing
        milestones = ["Loading local memory", "Checking Decide-later", "Preparing proposals"]
        let events = store.events(for: project.id)
        milestones.append("\(events.count) memory events")
        let queue = store.decideLater.filter { $0.project_id == project.id }
        milestones.append("\(queue.count) open Decide-later items")

        // Local proposal mode: disposable-looking artifacts from memory, never shared/protected preselected
        cards = buildCards(from: events, project: project, agent: agent)
        milestones.append("Built \(cards.count) action cards (conservative defaults unselected for shared/unknown)")

        let root = store.projectRoot(for: project)
        let payload = SkillComposer.reviewingPayload(project: project, store: store)
        let prompt = SkillComposer.compose(payload)
        await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
        usage = supervisor.usage
        milestones.append("Agent stage: \(supervisor.status)")
        stage = .actions
    }

    func buildLocalOnly(store: TraceStore, project: ProjectIndexRow, agent: AgentKind) {
        stage = .reviewing
        milestones = ["Offline reviewing from memory (no agent)"]
        let events = store.events(for: project.id)
        cards = buildCards(from: events, project: project, agent: agent)
        milestones.append("Built \(cards.count) action cards")
        stage = .actions
    }

    func toggle(id: String) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        if cards[idx].safety == .protected { return }
        cards[idx].selected.toggle()
    }

    func execute(store: TraceStore) {
        stage = .execute
        let selected = cards.filter(\.selected)
        var journal: [JournalEntry] = []
        var moved: [TrashService.Result] = []
        let neverTouch = store.settings.neverTouch
        let now = ISO8601DateFormatter().string(from: Date())

        for card in selected {
            for path in card.paths {
                let expected = card.fingerprints[path] ?? Fingerprint.of(path: path)
                let result = TrashService.moveToTrash(
                    path: path,
                    expectedFingerprint: expected,
                    neverTouch: neverTouch
                )
                moved.append(result)
                journal.append(JournalEntry(
                    id: UUID().uuidString,
                    selectionId: selectionId,
                    path: path,
                    fingerprintAtConfirm: expected,
                    fingerprintBeforeMove: result.fingerprintBefore,
                    trashDestination: result.trashURL?.path,
                    outcome: result.outcome.rawValue,
                    reason: result.reason,
                    at: now
                ))
            }
        }
        try? store.database.appendJournal(journal)
        store.refresh()
        results = moved
        stage = .done
    }

    private func buildCards(from events: [MemoryEvent], project: ProjectIndexRow, agent: AgentKind) -> [ActionCard] {
        var cards: [ActionCard] = []
        for event in events where event.event_type == "artifact" || event.event_type == nil {
            guard let location = event.what?.location, !location.isEmpty else { continue }
            let kind = (event.what?.kind ?? "").lowercased()
            let why = (event.why ?? "").lowercased()
            let consumers = event.project?.consumers ?? []
            let shared = consumers.count > 1 || consumers.contains(where: { $0.lowercased().contains("unknown") })
            let protected = TrashService.isNeverDelete(location, neverTouch: [])
                || why.contains("original") || why.contains("source of truth") || kind.contains("dataset")
            let disposableHint = ["cache", "build", "dist", "target", "tmp", "temp"].contains { kind.contains($0) || location.contains($0) }

            let safety: ActionCard.SafetyState
            if protected {
                safety = .protected
            } else if shared {
                safety = .shared
            } else if disposableHint {
                safety = .needsReview
            } else {
                safety = .unknown
            }

            let fp = FileManager.default.fileExists(atPath: location) ? Fingerprint.of(path: location) : "missing"
            cards.append(ActionCard(
                id: event.event_id,
                title: disposableHint ? "Remove \(event.what?.kind ?? "artifact")" : "Review \(event.what?.kind ?? "artifact")",
                summary: event.why ?? location,
                paths: [location],
                bytes: event.what?.bytes,
                safety: safety,
                projectId: project.id,
                agent: agent.rawValue,
                reversible: true,
                selected: false, // conservative: nothing preselected
                fingerprints: [location: fp]
            ))
        }
        return cards
    }
}
