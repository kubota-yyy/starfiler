import Foundation

struct KeybindingManager: Sendable {
    private typealias Sequence = [KeyEvent]

    private let bindingsByMode: [VimMode: [Sequence: KeyAction]]
    private let prefixesByMode: [VimMode: Set<Sequence>]

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        userConfigURL: URL? = nil
    ) {
        let resolvedUserConfigURL = userConfigURL ?? Self.defaultUserConfigURL(fileManager: fileManager, bundle: bundle)

        let defaultConfig = Self.loadConfig(from: bundle.url(forResource: "DefaultKeybindings", withExtension: "json"), fileManager: fileManager)
        let userConfig = Self.loadConfig(from: resolvedUserConfigURL, fileManager: fileManager)
        let mergedConfig = Self.merge(defaultConfig: defaultConfig, userConfig: userConfig)

        self.bindingsByMode = Self.buildBindings(from: mergedConfig)
        self.prefixesByMode = Self.buildPrefixes(from: bindingsByMode)
    }

    func lookup(sequence: [KeyEvent], mode: VimMode) -> KeyAction? {
        bindingsByMode[mode]?[sequence]
    }

    func hasPrefix(sequence: [KeyEvent], mode: VimMode) -> Bool {
        prefixesByMode[mode]?.contains(sequence) ?? false
    }

    static func defaultUserConfigURL(
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) -> URL? {
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.nilone.starfiler"

        guard let applicationSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        let configDirectory = applicationSupportURL
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Config", isDirectory: true)

        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        return configDirectory.appendingPathComponent("Keybindings.json", isDirectory: false)
    }

    private static func loadConfig(from url: URL?, fileManager: FileManager) -> KeybindingsConfig? {
        guard let url else {
            return nil
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(KeybindingsConfig.self, from: data)
    }

    private static func merge(defaultConfig: KeybindingsConfig?, userConfig: KeybindingsConfig?) -> KeybindingsConfig {
        var mergedBindings = defaultConfig?.bindings ?? [:]

        for (modeName, userModeBindings) in userConfig?.bindings ?? [:] {
            var modeBindings = mergedBindings[modeName] ?? [:]
            for (sequence, actionName) in userModeBindings {
                modeBindings[sequence] = actionName
            }
            mergedBindings[modeName] = modeBindings
        }

        return KeybindingsConfig(bindings: mergedBindings)
    }

    private static func buildBindings(from config: KeybindingsConfig) -> [VimMode: [Sequence: KeyAction]] {
        var result: [VimMode: [Sequence: KeyAction]] = [:]

        for (modeName, rawBindings) in config.bindings {
            guard let mode = VimMode(rawValue: modeName.lowercased()) else {
                continue
            }

            var modeBindings: [Sequence: KeyAction] = result[mode] ?? [:]

            for (rawSequence, rawActionName) in rawBindings {
                guard
                    let sequence = parseSequence(rawSequence),
                    let action = KeyAction(rawValue: rawActionName)
                else {
                    continue
                }

                modeBindings[sequence] = action
            }

            result[mode] = modeBindings
        }

        return result
    }

    private static func buildPrefixes(from bindings: [VimMode: [Sequence: KeyAction]]) -> [VimMode: Set<Sequence>] {
        var result: [VimMode: Set<Sequence>] = [:]

        for (mode, modeBindings) in bindings {
            var prefixes = Set<Sequence>()

            for sequence in modeBindings.keys where sequence.count > 1 {
                for index in 1 ..< sequence.count {
                    prefixes.insert(Array(sequence.prefix(index)))
                }
            }

            result[mode] = prefixes
        }

        return result
    }

    private static func parseSequence(_ rawSequence: String) -> Sequence? {
        let tokens = rawSequence
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !tokens.isEmpty else {
            return nil
        }

        var sequence: Sequence = []
        sequence.reserveCapacity(tokens.count)

        for token in tokens {
            guard let event = parseToken(token) else {
                return nil
            }
            sequence.append(event)
        }

        return sequence
    }

    private static func parseToken(_ rawToken: String) -> KeyEvent? {
        let segments = rawToken.split(separator: "-").map(String.init)

        guard let lastSegment = segments.last else {
            return nil
        }

        var modifiers: KeyModifiers = []

        if segments.count > 1 {
            for modifierToken in segments.dropLast() {
                guard let modifier = parseModifier(modifierToken) else {
                    return nil
                }
                modifiers.insert(modifier)
            }
        }

        guard let key = parseKey(lastSegment, modifiers: &modifiers) else {
            return nil
        }

        return KeyEvent(key: key, modifiers: modifiers)
    }

    private static func parseModifier(_ rawModifier: String) -> KeyModifiers? {
        switch rawModifier.lowercased() {
        case "shift":
            return .shift
        case "ctrl", "control":
            return .control
        case "alt", "opt", "option":
            return .option
        case "cmd", "command":
            return .command
        default:
            return nil
        }
    }

    private static func parseKey(_ rawKey: String, modifiers: inout KeyModifiers) -> String? {
        let normalized = rawKey.lowercased()

        let namedKeys: [String: String] = [
            "space": "Space",
            "return": "Return",
            "enter": "Return",
            "escape": "Escape",
            "esc": "Escape",
            "tab": "Tab",
            "backspace": "Backspace",
            "delete": "Delete",
            "pageup": "PageUp",
            "pagedown": "PageDown",
            "home": "Home",
            "end": "End",
            "left": "ArrowLeft",
            "arrowleft": "ArrowLeft",
            "right": "ArrowRight",
            "arrowright": "ArrowRight",
            "up": "ArrowUp",
            "arrowup": "ArrowUp",
            "down": "ArrowDown",
            "arrowdown": "ArrowDown"
        ]

        if let namedKey = namedKeys[normalized] {
            return namedKey
        }

        guard rawKey.count == 1 else {
            return nil
        }

        if rawKey != rawKey.lowercased(), rawKey.lowercased() != rawKey.uppercased() {
            modifiers.insert(.shift)
        }

        let scalar = String(rawKey)
        if scalar.lowercased() != scalar.uppercased() {
            return scalar.lowercased()
        }

        return scalar
    }
}
