import Foundation

/// Line-delimited JSON-RPC over a child process's stdio. Owns process-group kill on cancel.
final class JSONRPCProcess: @unchecked Sendable {
    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let lock = NSLock()
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var onNotification: ((String, [String: Any]) -> Void)?
    private var readerTask: Task<Void, Never>?
    private let jsonrpcHeader: Bool

    init(command: [String], cwd: URL?, jsonrpcHeader: Bool) throws {
        guard let exe = command.first else { throw AdapterError.binaryMissing("empty") }
        self.jsonrpcHeader = jsonrpcHeader
        process = Process()
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
        stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: which(exe) ?? exe)
        process.arguments = Array(command.dropFirst())
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if let cwd {
            process.currentDirectoryURL = cwd
        }
        // Own process group for cancel
        process.qualityOfService = .userInitiated
        try process.run()
        readerTask = Task { [weak self] in self?.readLoop() }
    }

    var isRunning: Bool { process.isRunning }

    func setNotificationHandler(_ handler: @escaping (String, [String: Any]) -> Void) {
        onNotification = handler
    }

    func request(_ method: String, params: [String: Any] = [:], timeout: TimeInterval = 60) async throws -> [String: Any] {
        let id: Int = lock.withLock {
            let value = nextId
            nextId += 1
            return value
        }
        var payload: [String: Any] = [
            "id": id,
            "method": method,
            "params": params,
        ]
        if jsonrpcHeader {
            payload["jsonrpc"] = "2.0"
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        var line = data
        line.append(contentsOf: "\n".utf8)
        try stdinPipe.fileHandleForWriting.write(contentsOf: line)

        return try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String: Any], Error>) in
                    self.lock.lock()
                    self.pending[id] = cont
                    self.lock.unlock()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AdapterError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func notify(_ method: String, params: [String: Any] = [:]) throws {
        var payload: [String: Any] = ["method": method, "params": params]
        if jsonrpcHeader {
            payload["jsonrpc"] = "2.0"
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        var line = data
        line.append(contentsOf: "\n".utf8)
        try stdinPipe.fileHandleForWriting.write(contentsOf: line)
    }

    func interruptThenKill() {
        if process.isRunning {
            process.interrupt()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [process] in
            if process.isRunning {
                process.terminate()
            }
        }
        // Best-effort process group signal
        let pid = process.processIdentifier
        if pid > 0 {
            kill(-pid, SIGTERM)
        }
    }

    func close() {
        readerTask?.cancel()
        interruptThenKill()
        try? stdinPipe.fileHandleForWriting.close()
    }

    private func readLoop() {
        let handle = stdoutPipe.fileHandleForReading
        var buffer = Data()
        while process.isRunning || handle.availableData.count > 0 {
            let chunk = handle.availableData
            if chunk.isEmpty {
                Thread.sleep(forTimeInterval: 0.05)
                if !process.isRunning { break }
                continue
            }
            buffer.append(chunk)
            while let range = buffer.range(of: Data("\n".utf8)) {
                let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                handleLine(line)
            }
        }
    }

    private func handleLine(_ line: Data) {
        guard !line.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        if let id = obj["id"] as? Int {
            lock.lock()
            let cont = pending.removeValue(forKey: id)
            lock.unlock()
            if let error = obj["error"] as? [String: Any] {
                cont?.resume(throwing: AdapterError.handshakeFailed(String(describing: error)))
            } else {
                let result = (obj["result"] as? [String: Any]) ?? obj
                cont?.resume(returning: result)
            }
            return
        }
        if let method = obj["method"] as? String {
            let params = (obj["params"] as? [String: Any]) ?? [:]
            onNotification?(method, params)
        }
    }
}

private func which(_ name: String) -> String? {
    if name.contains("/") { return name }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    proc.arguments = [name]
    let pipe = Pipe()
    proc.standardOutput = pipe
    try? proc.run()
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (text?.isEmpty == false) ? text : nil
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
