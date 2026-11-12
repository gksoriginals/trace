import CryptoKit
import Foundation

enum Fingerprint {
    static func of(path: String) -> String {
        of(url: URL(fileURLWithPath: path))
    }

    static func of(url: URL) -> String {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return "missing" }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber,
              let modified = attrs[.modificationDate] as? Date else {
            return "unknown"
        }
        let mtime = Int64(modified.timeIntervalSince1970 * 1_000_000_000)
        if isDir.boolValue {
            return "dir:\(size.intValue):\(mtime)"
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return "file:\(size.intValue):\(mtime):unreadable"
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1_048_576)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "file:\(size.intValue):\(mtime):\(digest)"
    }
}
