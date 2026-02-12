import Foundation

final class ConfigManager {
    private enum FileName {
        static let appConfig = "AppConfig.json"
        static let keybindingsConfig = "Keybindings.json"
        static let bookmarksConfig = "Bookmarks.json"
        static let batchRenamePresetsConfig = "BatchRenamePresets.json"
        static let syncletsConfig = "Synclets.json"
        static let visitHistoryConfig = "VisitHistory.json"
        static let pinnedItemsConfig = "PinnedItems.json"
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
        let loadedConfig = load(BookmarksConfig.self, from: bookmarksConfigURL) ?? BookmarksConfig()
        let migrationResult = loadedConfig.migratingLegacyPaths(fileManager: fileManager)
        if migrationResult.didChange {
            try? migrationResult.config.save(to: bookmarksConfigURL, fileManager: fileManager)
        }
        return migrationResult.config
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

    func loadBatchRenamePresetsConfig() -> BatchRenamePresetsConfig {
        load(BatchRenamePresetsConfig.self, from: batchRenamePresetsConfigURL) ?? BatchRenamePresetsConfig()
    }

    func saveBatchRenamePresetsConfig(_ config: BatchRenamePresetsConfig) throws {
        try save(config, to: batchRenamePresetsConfigURL)
    }

    var batchRenamePresetsConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.batchRenamePresetsConfig, isDirectory: false)
    }

    func loadSyncletsConfig() -> SyncletsConfig {
        load(SyncletsConfig.self, from: syncletsConfigURL) ?? SyncletsConfig()
    }

    func saveSyncletsConfig(_ config: SyncletsConfig) throws {
        try save(config, to: syncletsConfigURL)
    }

    var syncletsConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.syncletsConfig, isDirectory: false)
    }

    func loadVisitHistoryConfig() -> VisitHistoryConfig {
        load(VisitHistoryConfig.self, from: visitHistoryConfigURL) ?? VisitHistoryConfig()
    }

    func saveVisitHistoryConfig(_ config: VisitHistoryConfig) throws {
        try save(config, to: visitHistoryConfigURL)
    }

    var visitHistoryConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.visitHistoryConfig, isDirectory: false)
    }

    func loadPinnedItemsConfig() -> PinnedItemsConfig {
        load(PinnedItemsConfig.self, from: pinnedItemsConfigURL) ?? PinnedItemsConfig()
    }

    func savePinnedItemsConfig(_ config: PinnedItemsConfig) throws {
        try save(config, to: pinnedItemsConfigURL)
    }

    var pinnedItemsConfigURL: URL {
        configDirectory.appendingPathComponent(FileName.pinnedItemsConfig, isDirectory: false)
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
