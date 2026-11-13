import Foundation

/// Resolve agent CLIs for GUI apps, which inherit a minimal PATH (no `~/.local/bin`).
enum AgentPath {
    /// Absolute path to an executable, or nil if not found.
    static func resolve(_ name: String) -> String? {
        if name.contains("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        for dir in searchDirectories() {
            let candidate = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Whether a CLI name is available to Trace (login-shell PATH + common install dirs).
    static func isAvailable(_ name: String) -> Bool {
        resolve(name) != nil
    }

    /// Environment with an enriched PATH for spawned agent processes.
    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let enriched = searchDirectories().joined(separator: ":")
        if let existing = env["PATH"], !existing.isEmpty {
            env["PATH"] = enriched + ":" + existing
        } else {
            env["PATH"] = enriched
        }
        return env
    }

    private static func searchDirectories() -> [String] {
        var dirs: [String] = []
        let home = NSHomeDirectory()
        dirs.append(contentsOf: [
            home + "/.local/bin",
            home + "/.cargo/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ])
        // Login-shell PATH (zsh/bash) so GUI launches see the same CLIs as Terminal.
        if let shellPath = loginShellPATH() {
            dirs.append(contentsOf: shellPath.split(separator: ":").map(String.init))
        }
        if let processPath = ProcessInfo.processInfo.environment["PATH"] {
            dirs.append(contentsOf: processPath.split(separator: ":").map(String.init))
        }
        var seen = Set<String>()
        return dirs.filter { dir in
            guard !dir.isEmpty, seen.insert(dir).inserted else { return false }
            return true
        }
    }

    private static var cachedLoginPATH: String?
    private static let cacheLock = NSLock()

    private static func loginShellPATH() -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedLoginPATH { return cachedLoginPATH }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-l", "-c", "printf %s \"$PATH\""]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        cachedLoginPATH = text
        return text
    }
}
