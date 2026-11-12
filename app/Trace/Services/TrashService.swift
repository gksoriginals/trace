import Foundation

/// Native Trash boundary. Agent output cannot invent targets.
enum TrashService {
    enum Outcome: String {
        case moved, skipped, failed
    }

    struct Result {
        var path: String
        var outcome: Outcome
        var reason: String?
        var trashURL: URL?
        var fingerprintBefore: String?
    }

    static func isNeverDelete(_ path: String, neverTouch: [String]) -> Bool {
        let resolved = (path as NSString).expandingTildeInPath
        let prefixes = ["/System", "/usr", "/bin", "/sbin", "/Library", "/private/var/db"]
        for prefix in prefixes where resolved == prefix || resolved.hasPrefix(prefix + "/") {
            return true
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for suffix in ["/Documents", "/Pictures", "/Movies", "/Music", "/Library/Mail", "/.ssh", "/.gnupg"] {
            let protected = home + suffix
            if resolved == protected || resolved.hasPrefix(protected + "/") { return true }
        }
        let name = URL(fileURLWithPath: resolved).lastPathComponent
        if [".env", ".env.local", "id_rsa", "id_ed25519", "credentials.json"].contains(name) {
            return true
        }
        for item in neverTouch {
            let p = (item as NSString).expandingTildeInPath
            if resolved == p || resolved.hasPrefix(p.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/")
                || resolved.hasPrefix(p + "/") {
                return true
            }
        }
        return false
    }

    static func moveToTrash(
        path: String,
        expectedFingerprint: String,
        neverTouch: [String]
    ) -> Result {
        if isNeverDelete(path, neverTouch: neverTouch) {
            return Result(path: path, outcome: .skipped, reason: "never-delete", trashURL: nil, fingerprintBefore: nil)
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Result(path: path, outcome: .skipped, reason: "missing", trashURL: nil, fingerprintBefore: nil)
        }
        let before = Fingerprint.of(url: url)
        guard before == expectedFingerprint else {
            return Result(path: path, outcome: .skipped, reason: "fingerprint-mismatch", trashURL: nil, fingerprintBefore: before)
        }
        do {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
            return Result(
                path: path,
                outcome: .moved,
                reason: nil,
                trashURL: resulting as URL?,
                fingerprintBefore: before
            )
        } catch {
            return Result(path: path, outcome: .failed, reason: error.localizedDescription, trashURL: nil, fingerprintBefore: before)
        }
    }

    static func undo(entry: JournalEntry) -> String? {
        guard entry.outcome == Outcome.moved.rawValue,
              let trashPath = entry.trashDestination else {
            return "Nothing to restore for this journal row."
        }
        let trashURL = URL(fileURLWithPath: trashPath)
        let dest = URL(fileURLWithPath: entry.path)
        if FileManager.default.fileExists(atPath: dest.path) {
            return "Restore refused: destination already exists."
        }
        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: trashURL, to: dest)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
