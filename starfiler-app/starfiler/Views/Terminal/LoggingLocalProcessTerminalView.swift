import AppKit
import SwiftTerm

final class LoggingLocalProcessTerminalView: LocalProcessTerminalView {
    var onDataReceived: ((String) -> Void)?
}
