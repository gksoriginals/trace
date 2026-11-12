import Foundation

enum AgentDetector {
    static func detect() -> [AgentStatus] {
        [
            status(id: "cursor", displayName: "Cursor", candidates: ["agent", "cursor-agent"]),
            status(id: "codex", displayName: "Codex", candidates: ["codex"]),
            AgentStatus(id: "claude", displayName: "Claude (later)", binary: nil, version: nil, ready: .unsupported),
            AgentStatus(id: "gemini", displayName: "Gemini (later)", binary: nil, version: nil, ready: .unsupported),
        ]
    }

    private static func status(id: String, displayName: String, candidates: [String]) -> AgentStatus {
        for name in candidates {
            if let path = which(name) {
                let version = runVersion(path)
                return AgentStatus(id: id, displayName: displayName, binary: path, version: version, ready: .ready)
            }
        }
        return AgentStatus(id: id, displayName: displayName, binary: nil, version: nil, ready: .absent)
    }

    private static func which(_ name: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [name]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (text?.isEmpty == false) ? text : nil
        } catch {
            return nil
        }
    }

    private static func runVersion(_ path: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["--version"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.split(separator: "\n").first.map(String.init)
        } catch {
            return nil
        }
    }
}
