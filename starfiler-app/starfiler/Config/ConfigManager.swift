import Foundation

final class ConfigManager {
    private enum FileName {
        static let appConfig = "AppConfig.json"
        static let keybindingsConfig = "Keybindings.json"
        static let bookmarksConfig = "Bookmarks.json"
    }

    let configDirectory: URL

    private let fileManager: FileManager
    private let bundleIdentifier: String

    init(
        fileManager: FileManager = .default,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.nilone.starfiler",
        configDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.bundleIdentifier = bundleIdentifier

        if let configDirectory {
            self.configDirectory = configDirectory
        } else {
            self.configDirectory = Self.defaultConfigDirectory(
                fileManager: fileManager,
                bundleIdentifier: bundleIdentifier
            )
        }

        createConfigDirectoryIfNeeded()
    }

    func loadAppConfig() -> AppConfig {
        load(AppConfig.self, from: appConfigURL) ?? AppConfig()
    }

    func saveAppConfig(_ config: AppConfig) throws {
        try save(config, to: appConfigURL)
    }

    func loadKeybindingsConfig() -> KeybindingsConfig {
        load(KeybindingsConfig.self, from: keybindingsConfigURL) ?? KeybindingsConfig()
    }

    func saveKeybindingsConfig(_ config: KeybindingsConfig) throws {
        try save(config, to: keybindingsConfigURL)
    }

    func loadBookmarksConfig() -> BookmarksConfig {
        load(BookmarksConfig.self, from: bookmarksConfigURL) ?? BookmarksConfig()
    }

    func saveBookmarksConfig(_ config: BookmarksConfig) throws {
        try config.save(to: bookmarksConfigURL, fileManager: fileManager)
    }

    var appConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.appConfig, isDirectory: false)
    }

    var keybindingsConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.keybindingsConfig, isDirectory: false)
    }

    var bookmarksConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.bookmarksConfig, isDirectory: false)
    }

    private static func defaultConfigDirectory(fileManager: FileManager, bundleIdentifier: String) -> URL {
        let baseURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? UserPaths.homeDirectoryURL

        return baseURL
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Config", isDirectory: true)
    }

    private func createConfigDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: configDirectory.path) else {
            return
        }

        try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
