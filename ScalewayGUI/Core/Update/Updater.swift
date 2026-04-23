import Foundation
import AppKit

@MainActor
final class Updater: NSObject {
    private var downloadTask: URLSessionDownloadTask?
    private var onProgress: ((Double) -> Void)?
    private var onComplete: ((URL) -> Void)?
    private var onError: ((String) -> Void)?

    func download(
        url: URL,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (URL) -> Void,
        onError: @escaping (String) -> Void
    ) async {
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        downloadTask = task
        task.resume()
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    func install(mountPoint: URL) {
        let installPath = Bundle.main.bundleURL.path
        let scriptPath = NSTemporaryDirectory() + "scalewaygui_update.sh"
        let mountPointPath = mountPoint.path

        let script = """
        #!/bin/bash
        sleep 2
        rm -rf \(shellEscape(installPath))
        cp -R \(shellEscape(mountPointPath))/ScalewayGUI.app \(shellEscape(installPath))
        open \(shellEscape(installPath))
        hdiutil detach \(shellEscape(mountPointPath)) -quiet 2>/dev/null || true
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try? process.run()
    }

    private func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

extension Updater: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.onProgress?(progress)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let dmgPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScalewayGUI_update.dmg")
        do {
            if FileManager.default.fileExists(atPath: dmgPath.path) {
                try FileManager.default.removeItem(at: dmgPath)
            }
            try FileManager.default.moveItem(at: location, to: dmgPath)
        } catch {
            Task { @MainActor in self.onError?("Failed to save download: \(error.localizedDescription)") }
            return
        }

        let mountPoint = NSTemporaryDirectory() + "ScalewayGUI_mount"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgPath.path, "-nobrowse", "-quiet", "-mountpoint", mountPoint]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Task { @MainActor in self.onError?("Failed to mount update: \(error.localizedDescription)") }
            return
        }

        guard process.terminationStatus == 0 else {
            Task { @MainActor in self.onError?("Failed to mount disk image.") }
            return
        }

        let mountURL = URL(fileURLWithPath: mountPoint)
        Task { @MainActor in self.onComplete?(mountURL) }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor in self.onError?(error.localizedDescription) }
    }
}
