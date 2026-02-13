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

    // MARK: - Custom Config Directory

    private static let customConfigDirectoryKey = "customConfigDirectory"

    static func customConfigDirectoryURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: customConfigDirectoryKey) else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func setCustomConfigDirectory(_ url: URL?) {
        if let url {
            UserDefaults.standard.set(url.path, forKey: customConfigDirectoryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customConfigDirectoryKey)
        }
    }

    static func defaultFallbackConfigDirectory(
        fileManager: FileManager = .default,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.nilone.starfiler"
    ) -> URL {
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

    static func existingConfigFileNames(in directory: URL, fileManager: FileManager = .default) -> [String] {
        guard fileManager.fileExists(atPath: directory.path),
              let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.lastPathComponent }
    }

    static func migrateConfigFiles(from source: URL, to destination: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            let destFileURL = destination.appendingPathComponent(fileURL.lastPathComponent)
            if fileManager.fileExists(atPath: destFileURL.path) {
                try fileManager.removeItem(at: destFileURL)
            }
            try fileManager.copyItem(at: fileURL, to: destFileURL)
        }
    }

    private static func defaultConfigDirectory(fileManager: FileManager, bundleIdentifier: String) -> URL {
        if let customURL = customConfigDirectoryURL() {
            return customURL
        }

        return defaultFallbackConfigDirectory(fileManager: fileManager, bundleIdentifier: bundleIdentifier)
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
