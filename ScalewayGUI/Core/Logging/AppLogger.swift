import OSLog

enum AppLogger {
    static let logger = Logger(subsystem: "com.scaleway.gui", category: "app")
}
