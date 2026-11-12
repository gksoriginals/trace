import Foundation

/// App-only writer. Skills never open this file.
final class AppPreferencesStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> AppPreferences {
        let url = TracePaths.preferencesURL
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let prefs = try? decoder.decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return prefs
    }

    func save(_ prefs: AppPreferences) throws {
        try fileManager.createDirectory(at: TracePaths.appSupport, withIntermediateDirectories: true)
        let data = try encoder.encode(prefs)
        let tmp = TracePaths.appSupport.appendingPathComponent("preferences.json.tmp")
        try data.write(to: tmp, options: .atomic)
        let dest = TracePaths.preferencesURL
        if fileManager.fileExists(atPath: dest.path) {
            _ = try fileManager.replaceItemAt(dest, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: dest)
        }
    }
}
