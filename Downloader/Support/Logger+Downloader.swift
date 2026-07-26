import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.appleapplab.Downloader"

    static let launcher = Logger(subsystem: subsystem, category: "launcher")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let ytdlp = Logger(subsystem: subsystem, category: "ytdlp")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let statusItem = Logger(subsystem: subsystem, category: "statusItem")
}
