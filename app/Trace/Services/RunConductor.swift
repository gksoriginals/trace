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

    func startReviewing(store: TraceStore, projects: [ProjectIndexRow], agent: AgentKind, supervisor: SessionSupervisor) async {
        stage = .reviewing
        milestones = ["Loading local memory", "Checking Decide-later", "Preparing proposals"]
        var built: [ActionCard] = []
        for project in projects {
            let events = store.events(for: project.id)
            milestones.append("\(project.displayName): \(events.count) memory events")
            built.append(contentsOf: buildCards(from: events, project: project, agent: agent))
        }
        let projectIds = Set(projects.map(\.id))
        let queue = store.decideLater.filter { projectIds.contains($0.project_id ?? "") }
        milestones.append("\(queue.count) open Decide-later items in scope")
        cards = built
        milestones.append("Built \(cards.count) action cards (conservative defaults unselected for shared/unknown)")

        let root = projects.first.map { store.projectRoot(for: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.path
        let payload = SkillComposer.reviewingPayload(projects: projects, store: store)
        let prompt = SkillComposer.compose(payload)
        await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
        usage = supervisor.usage
        milestones.append("Agent stage: \(supervisor.status)")
        stage = .actions
    }

    func buildLocalOnly(store: TraceStore, project: ProjectIndexRow, agent: AgentKind) {
        buildLocalOnly(store: store, projects: [project], agent: agent)
    }

    func buildLocalOnly(store: TraceStore, projects: [ProjectIndexRow], agent: AgentKind) {
        stage = .reviewing
        milestones = ["Offline reviewing from memory (no agent)", "\(projects.count) project(s) in scope"]
        var built: [ActionCard] = []
        for project in projects {
            let events = store.events(for: project.id)
            built.append(contentsOf: buildCards(from: events, project: project, agent: agent))
        }
        cards = built
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
