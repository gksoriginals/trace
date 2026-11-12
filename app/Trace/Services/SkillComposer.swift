import Foundation

/// Mode 2: compose skill SKILL.md + params + inputs for a harness agent instance.
@MainActor
enum SkillComposer {
    struct Payload {
        var skillIds: [String]
        var params: [String: Any]
        var inputs: [String: Any]
        var task: String
    }

    static func skillsRoot() -> URL? {
        if let recorded = try? String(contentsOfFile: NSHomeDirectory() + "/.trace/skills_source.txt", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           FileManager.default.fileExists(atPath: recorded + "/install.sh") {
            return URL(fileURLWithPath: recorded)
        }
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("skills"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("projects/trace-1/skills"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("install.sh").path) }
    }

    static func skillMarkdown(folder: String) -> String {
        guard let root = skillsRoot() else { return "(skills root missing)" }
        let url = root.appendingPathComponent(folder).appendingPathComponent("SKILL.md")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "(missing \(folder)/SKILL.md)"
    }

    static func compose(_ payload: Payload) -> String {
        let folders = [
            "hygienic_setup": "hygienic-setup",
            "hygienic-setup": "hygienic-setup",
            "session_end": "session-end-cleanup",
            "session-end-cleanup": "session-end-cleanup",
            "memory_writer": "memory-writer",
            "memory-writer": "memory-writer",
            "prepare_home": "prepare-home",
            "prepare-home": "prepare-home",
        ]
        var parts: [String] = [
            "You are running Trace skills inside this coding-agent session.",
            "Follow the named skill instructions. Write only the paths listed in inputs.",
            "Do not permanently delete files. Trash only exact consented paths.",
            "Do not invent Execute targets for the Trace app.",
            "",
            "## Task\n\(payload.task)",
            "",
            "## Params\n```json\n\(jsonString(payload.params))\n```",
            "",
            "## Inputs\n```json\n\(jsonString(payload.inputs))\n```",
            "",
        ]
        for id in payload.skillIds {
            let folder = folders[id] ?? id
            parts.append("## Skill: \(id)\n\(skillMarkdown(folder: folder))\n")
        }
        return parts.joined(separator: "\n")
    }

    static func prepareHomePayload(project: ProjectIndexRow, store: TraceStore) -> Payload {
        let root = store.projectRoot(for: project)
        let trace = URL(fileURLWithPath: root).appendingPathComponent(".trace")
        return Payload(
            skillIds: ["prepare-home"],
            params: [
                "project_id": project.id,
                "roots": project.roots ?? [root],
                "never_touch": store.settings.neverTouch,
                "retention_days": 30,
            ],
            inputs: [
                "index_path": store.indexURL.path,
                "memory_dir": trace.appendingPathComponent("memory").path,
                "decide_later_path": trace.appendingPathComponent("decide-later.md").path,
                "insights_path": trace.appendingPathComponent("insights.md").path,
            ],
            task: "Prepare Home insight cards for this project. Update insights.md only."
        )
    }

    static func reviewingPayload(project: ProjectIndexRow, store: TraceStore) -> Payload {
        let root = store.projectRoot(for: project)
        let trace = URL(fileURLWithPath: root).appendingPathComponent(".trace")
        return Payload(
            skillIds: ["prepare-home", "memory-writer"],
            params: [
                "project_id": project.id,
                "roots": project.roots ?? [root],
                "never_touch": store.settings.neverTouch,
                "mode": "proposal",
            ],
            inputs: [
                "index_path": store.indexURL.path,
                "memory_dir": trace.appendingPathComponent("memory").path,
                "decide_later_path": trace.appendingPathComponent("decide-later.md").path,
                "insights_path": trace.appendingPathComponent("insights.md").path,
            ],
            task: """
            Trace Reviewing (read-only / proposal mode). Inspect coverage gaps using memory. \
            Update insights and Decide-later. Propose disposable leftovers as suggestions only. \
            Do not Trash or permanently delete. Do not repeat installs already recorded.
            """
        )
    }

    private static func jsonString(_ obj: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}
