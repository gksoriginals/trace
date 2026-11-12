import Foundation

struct SkillInstallResult: Equatable {
    var ok: Bool
    var output: String
}

enum SkillInstaller {
    /// Runs skills/install.sh for whole-agent install and optional project lines.
    static func install(skillsRoot: URL, projects: [String], dryRun: Bool = false) -> SkillInstallResult {
        let script = skillsRoot.appendingPathComponent("install.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path)
                || FileManager.default.fileExists(atPath: script.path) else {
            return SkillInstallResult(ok: false, output: "Missing \(script.path). Set TRACE_SKILLS_ROOT or pick the repo skills folder.")
        }
        var arguments = [script.path]
        if dryRun { arguments.append("--dry-run") }
        // install.sh accepts one --project; call once per project after a base install
        let base = run(script: script.path, args: dryRun ? ["--dry-run"] : [])
        if !base.ok { return base }
        var logs = [base.output]
        for project in projects {
            var args: [String] = []
            if dryRun { args.append("--dry-run") }
            args += ["--project", project]
            let result = run(script: script.path, args: args)
            logs.append(result.output)
            if !result.ok {
                return SkillInstallResult(ok: false, output: logs.joined(separator: "\n"))
            }
        }
        return SkillInstallResult(ok: true, output: logs.joined(separator: "\n"))
    }

    private static func run(script: String, args: [String]) -> SkillInstallResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script] + args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return SkillInstallResult(ok: proc.terminationStatus == 0, output: text)
        } catch {
            return SkillInstallResult(ok: false, output: error.localizedDescription)
        }
    }
}
