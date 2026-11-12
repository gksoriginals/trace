import Foundation

enum SkillInstaller {
    static func install(projectPath: String?) throws -> String {
        let repoSkills = locateSkillsRoot()
        guard let repoSkills else {
            throw NSError(domain: "Trace", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find skills/ next to the app or via ~/.trace/skills_source.txt",
            ])
        }
        let script = repoSkills.appendingPathComponent("install.sh")
        var args = [script.path]
        if let projectPath, !projectPath.isEmpty {
            args += ["--project", projectPath]
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            throw NSError(domain: "Trace", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: text.isEmpty ? "install.sh failed" : text,
            ])
        }
        return text
    }

    private static func locateSkillsRoot() -> URL? {
        if let recorded = try? String(contentsOfFile: NSHomeDirectory() + "/.trace/skills_source.txt", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !recorded.isEmpty,
           FileManager.default.fileExists(atPath: recorded + "/install.sh") {
            return URL(fileURLWithPath: recorded)
        }
        // Dev: app/ next to skills/
        let bundle = Bundle.main.bundleURL
        let candidates = [
            bundle.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("skills"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("skills"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("projects/trace-1/skills"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("install.sh").path) }
    }
}
