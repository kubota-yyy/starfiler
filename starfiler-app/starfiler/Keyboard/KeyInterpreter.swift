import Foundation

enum KeyInterpreterResult: Equatable, Sendable {
    case action(KeyAction)
    case pending
    case unhandled
}

struct KeyInterpreter: Sendable {
    private let keybindingManager: KeybindingManager

    private(set) var mode: VimMode
    private(set) var timeout: TimeInterval

    private var pendingSequence: [KeyEvent]
    private var lastInputDate: Date?

    init(
        keybindingManager: KeybindingManager = KeybindingManager(),
        mode: VimMode = .normal,
        timeout: TimeInterval = 0.3
    ) {
        self.keybindingManager = keybindingManager
        self.mode = mode
        self.timeout = max(0, timeout)
        self.pendingSequence = []
        self.lastInputDate = nil
    }

    mutating func setMode(_ mode: VimMode) {
        guard self.mode != mode else {
            return
        }

        self.mode = mode
        clearPendingSequence()
    }

    mutating func setTimeout(_ timeout: TimeInterval) {
        self.timeout = max(0, timeout)
    }

    mutating func clearPendingSequence() {
        pendingSequence.removeAll(keepingCapacity: false)
        lastInputDate = nil
    }

    mutating func interpret(_ event: KeyEvent, now: Date = Date()) -> KeyInterpreterResult {
        if event.modifiers.contains(.command) {
            clearPendingSequence()
            if let action = keybindingManager.lookup(sequence: [event], mode: mode) {
                return .action(action)
            }
            return .unhandled
        }

        expirePendingSequenceIfNeeded(now: now)

        let hadPendingSequence = !pendingSequence.isEmpty
        pendingSequence.append(event)

        let currentAttempt = evaluatePendingSequence(now: now)
        if currentAttempt != .unhandled {
            return currentAttempt
        }

        if hadPendingSequence {
            pendingSequence = [event]
            let singleKeyAttempt = evaluatePendingSequence(now: now)
            if singleKeyAttempt != .unhandled {
                return singleKeyAttempt
            }
        }

        clearPendingSequence()
        return .unhandled
    }

    private mutating func evaluatePendingSequence(now: Date) -> KeyInterpreterResult {
        if let action = keybindingManager.lookup(sequence: pendingSequence, mode: mode) {
            clearPendingSequence()
            return .action(action)
        }

        if keybindingManager.hasPrefix(sequence: pendingSequence, mode: mode) {
            lastInputDate = now
            return .pending
        }

        return .unhandled
    }

    private mutating func expirePendingSequenceIfNeeded(now: Date) {
        guard
            !pendingSequence.isEmpty,
            let lastInputDate,
            now.timeIntervalSince(lastInputDate) >= timeout
        else {
            return
        }

        clearPendingSequence()
    }
}
