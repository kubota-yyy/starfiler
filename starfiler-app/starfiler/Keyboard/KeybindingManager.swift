import Foundation

struct KeybindingHintCandidate: Equatable, Sendable {
    let sequence: [KeyEvent]
    let action: KeyAction
}

struct KeybindingManager: Sendable {
    private typealias Sequence = [KeyEvent]

    private let bindingsByMode: [VimMode: [Sequence: KeyAction]]
    private let prefixesByMode: [VimMode: Set<Sequence>]
    private let shortcutsByMode: [VimMode: [KeyAction: [String]]]

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
        self.shortcutsByMode = Self.buildShortcuts(from: mergedConfig)
    }

    func lookup(sequence: [KeyEvent], mode: VimMode) -> KeyAction? {
        bindingsByMode[mode]?[sequence]
    }

    func hasPrefix(sequence: [KeyEvent], mode: VimMode) -> Bool {
        prefixesByMode[mode]?.contains(sequence) ?? false
    }

    func shortcuts(for action: KeyAction, mode: VimMode = .normal) -> [String] {
        shortcutsByMode[mode]?[action] ?? []
    }

    func candidates(
        requiringInitialModifiers requiredModifiers: KeyModifiers,
        mode: VimMode
    ) -> [KeybindingHintCandidate] {
        guard !requiredModifiers.isEmpty else {
            return []
        }

        let modeBindings = bindingsByMode[mode] ?? [:]
        let filtered = modeBindings.compactMap { sequence, action -> KeybindingHintCandidate? in
            guard let first = sequence.first else {
                return nil
            }
            guard Self.isSuperset(first.modifiers, of: requiredModifiers) else {
                return nil
            }
            return KeybindingHintCandidate(sequence: sequence, action: action)
        }

        return filtered.sorted(by: Self.compareCandidates)
    }

    func candidates(
        startingWith prefix: [KeyEvent],
        mode: VimMode
    ) -> [KeybindingHintCandidate] {
        guard !prefix.isEmpty else {
            return []
        }

        let modeBindings = bindingsByMode[mode] ?? [:]
        let filtered = modeBindings.compactMap { sequence, action -> KeybindingHintCandidate? in
            guard Self.hasPrefix(sequence, prefix: prefix) else {
                return nil
            }
            return KeybindingHintCandidate(sequence: sequence, action: action)
        }

        return filtered.sorted(by: Self.compareCandidates)
    }

    static func defaultUserConfigURL(
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) -> URL? {
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.nilone.starfiler"
        let configManager = ConfigManager(fileManager: fileManager, bundleIdentifier: bundleIdentifier)
        return configManager.keybindingsConfigURL
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

    static func merge(defaultConfig: KeybindingsConfig?, userConfig: KeybindingsConfig?) -> KeybindingsConfig {
        var mergedBindings = defaultConfig?.bindings ?? [:]

        for (modeName, userModeBindings) in userConfig?.bindings ?? [:] {
            var modeBindings = mergedBindings[modeName] ?? [:]
            for (sequence, actionName) in userModeBindings {
                if KeybindingsConfig.isUnboundActionName(actionName) {
                    modeBindings.removeValue(forKey: sequence)
                } else {
                    modeBindings[sequence] = actionName
                }
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
                    let action = KeyAction.fromConfigName(rawActionName)
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

    private static func buildShortcuts(from config: KeybindingsConfig) -> [VimMode: [KeyAction: [String]]] {
        var result: [VimMode: [KeyAction: [String]]] = [:]

        for (modeName, rawBindings) in config.bindings {
            guard let mode = VimMode(rawValue: modeName.lowercased()) else {
                continue
            }

            var modeShortcuts = result[mode] ?? [:]

            for (rawSequence, rawActionName) in rawBindings.sorted(by: { $0.key < $1.key }) {
                guard
                    parseSequence(rawSequence) != nil,
                    let action = KeyAction.fromConfigName(rawActionName)
                else {
                    continue
                }

                var actionShortcuts = modeShortcuts[action] ?? []
                if !actionShortcuts.contains(rawSequence) {
                    actionShortcuts.append(rawSequence)
                }
                modeShortcuts[action] = actionShortcuts
            }

            result[mode] = modeShortcuts
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

    private static func hasPrefix(_ sequence: Sequence, prefix: Sequence) -> Bool {
        guard sequence.count >= prefix.count else {
            return false
        }

        for (index, keyEvent) in prefix.enumerated() where sequence[index] != keyEvent {
            return false
        }

        return true
    }

    private static func isSuperset(_ modifiers: KeyModifiers, of requiredModifiers: KeyModifiers) -> Bool {
        modifiers.intersection(requiredModifiers) == requiredModifiers
    }

    private static func compareCandidates(_ lhs: KeybindingHintCandidate, _ rhs: KeybindingHintCandidate) -> Bool {
        if lhs.sequence.count != rhs.sequence.count {
            return lhs.sequence.count < rhs.sequence.count
        }

        let lhsKey = sequenceSortKey(lhs.sequence)
        let rhsKey = sequenceSortKey(rhs.sequence)
        if lhsKey != rhsKey {
            return lhsKey < rhsKey
        }

        return lhs.action.rawValue < rhs.action.rawValue
    }

    private static func sequenceSortKey(_ sequence: Sequence) -> String {
        sequence.map { event in
            var components: [String] = []

            if event.modifiers.contains(.control) {
                components.append("Ctrl")
            }
            if event.modifiers.contains(.shift) {
                components.append("Shift")
            }
            if event.modifiers.contains(.option) {
                components.append("Alt")
            }
            if event.modifiers.contains(.command) {
                components.append("Cmd")
            }

            components.append(event.key)
            return components.joined(separator: "-")
        }
        .joined(separator: " ")
    }
}
