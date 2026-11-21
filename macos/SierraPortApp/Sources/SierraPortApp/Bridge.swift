import Foundation

final class SierraPortBridge: @unchecked Sendable {
    let binaryPath: String?

    init() {
        self.binaryPath = Self.locateBinary()
    }

    static func locateBinary() -> String? {
        let fm = FileManager.default
        var candidates: [String] = []

        // 1. Embedded inside .app bundle Resources
        if let resPath = Bundle.main.resourcePath {
            candidates.append((resPath as NSString).appendingPathComponent("sierraport"))
        }

        #if DEBUG
        // 2. Relative to current working directory / project root (dev mode only)
        let cwd = fm.currentDirectoryPath
        candidates.append((cwd as NSString).appendingPathComponent("target/release/sierraport"))
        candidates.append((cwd as NSString).appendingPathComponent("target/debug/sierraport"))
        candidates.append(((cwd as NSString).deletingLastPathComponent as NSString).appendingPathComponent("target/release/sierraport"))
        candidates.append((((cwd as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent as NSString).appendingPathComponent("target/release/sierraport"))

        // 3. Relative to executable path (dev mode only)
        let execDir = (Bundle.main.executablePath as NSString?)?.deletingLastPathComponent ?? ""
        if !execDir.isEmpty {
            var dir = execDir as NSString
            for _ in 0..<5 {
                candidates.append(dir.appendingPathComponent("target/release/sierraport"))
                dir = dir.deletingLastPathComponent as NSString
            }
        }
        #endif

        // 4. Common installed locations
        let home = NSHomeDirectory()
        candidates.append("\(home)/.cargo/bin/sierraport")
        candidates.append("/usr/local/bin/sierraport")
        candidates.append("/opt/homebrew/bin/sierraport")

        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    struct ExecutionResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let durationMs: Int
    }

    func run(arguments: [String]) async -> ExecutionResult {
        guard let bin = binaryPath else {
            return ExecutionResult(
                stdout: "",
                stderr: "Could not locate 'sierraport' binary. Run `cargo build --release` first.",
                exitCode: 127,
                durationMs: 0
            )
        }

        return await Task.detached(priority: .userInitiated) {
            Self.runSync(bin: bin, arguments: arguments)
        }.value
    }

    private static func runSync(bin: String, arguments: [String]) -> ExecutionResult {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ExecutionResult(
                stdout: "",
                stderr: "Failed to launch sierraport: \(error.localizedDescription)",
                exitCode: 1,
                durationMs: 0
            )
        }

        // Drain stdout and stderr concurrently to avoid >64KB pipe buffer deadlocks
        let group = DispatchGroup()
        var outData = Data()
        var errData = Data()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            try? outPipe.fileHandleForReading.close()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            try? errPipe.fileHandleForReading.close()
            group.leave()
        }

        group.wait()
        process.waitUntilExit()

        let elapsed = Int(Date().timeIntervalSince(start) * 1000.0)
        return ExecutionResult(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus,
            durationMs: elapsed
        )
    }

    /// Starts a live `sierraport stream` subprocess and delivers decoded `StreamTick`s.
    func startStream(
        intervalMs: Int = 1000,
        extraArgs: [String] = [],
        onTick: @escaping @Sendable (StreamTick) -> Void
    ) -> Process? {
        guard let bin = binaryPath else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = ["stream", "-i", "\(intervalMs)"] + extraArgs

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let bufferLock = NSLock()
        var buffer = Data()
        let maxBufferBytes = 4 * 1024 * 1024
        let decoder = JSONDecoder()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                try? handle.close()
                return
            }

            var linesToDecode: [Data] = []
            bufferLock.lock()
            buffer.append(chunk)
            if buffer.count > maxBufferBytes {
                buffer.removeAll(keepingCapacity: false)
            }
            while let newlineRange = buffer.range(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                if !lineData.isEmpty {
                    linesToDecode.append(lineData)
                }
            }
            bufferLock.unlock()

            for lineData in linesToDecode {
                if let tick = try? decoder.decode(StreamTick.self, from: lineData) {
                    onTick(tick)
                }
            }
        }

        process.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
        }

        do {
            try process.run()
            return process
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            return nil
        }
    }
}
