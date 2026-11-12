import Foundation

enum TracePaths {
    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var traceHome: URL {
        if let env = ProcessInfo.processInfo.environment["TRACE_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(".trace", isDirectory: true)
    }

    static var indexURL: URL {
        traceHome.appendingPathComponent("index.json")
    }

    static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Trace", isDirectory: true)
    }

    static var preferencesURL: URL {
        appSupport.appendingPathComponent("preferences.json")
    }

    /// Repo skills root when running from a checkout; optional override.
    static var skillsSource: URL? {
        if let env = ProcessInfo.processInfo.environment["TRACE_SKILLS_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let marker = traceHome.appendingPathComponent("skills_source.txt")
        if let text = try? String(contentsOf: marker, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return URL(fileURLWithPath: trimmed, isDirectory: true)
            }
        }
        // Relative to the running binary in a source-built app is unreliable;
        // Setup also accepts a folder picker.
        return nil
    }
}
