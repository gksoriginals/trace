import Foundation

enum AgentProbe {
    static func probeAll() async -> (cursor: (String?, AgentAuthStatus), codex: (String?, AgentAuthStatus)) {
        async let c = AgentRegistry.adapter(for: .cursor).probe()
        async let x = AgentRegistry.adapter(for: .codex).probe()
        let (cr, xr) = await (c, x)
        return ((cr.version, cr.auth), (xr.version, xr.auth))
    }

    static func suggestProjectRoots() -> [String] {
        var roots: [String] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("code"),
            home.appendingPathComponent("src"),
        ]
        for dir in candidates {
            guard let kids = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for kid in kids.prefix(12) {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: kid.path, isDirectory: &isDir), isDir.boolValue {
                    let git = kid.appendingPathComponent(".git")
                    if FileManager.default.fileExists(atPath: git.path) {
                        roots.append(kid.path)
                    }
                }
            }
        }
        return Array(Set(roots)).sorted()
    }
}
