import Foundation

enum KeyAction: String, Codable, CaseIterable, Sendable {
    case cursorUp
    case cursorDown
    case cursorLeft
    case cursorRight
    case pageUp
    case pageDown
    case goToTop
    case goToBottom
    case goBack
    case goForward
    case goToParent
    case goHome
    case goDesktop
    case goDocuments
    case goDownloads
    case goApplications
    case enterDirectory
    case switchPane
    case toggleMark
    case markAll
    case clearMarks
    case enterVisualMode
    case exitVisualMode
    case copy
    case copySelectedItemPath
    case paste
    case move
    case delete
    case rename
    case createDirectory
    case enterFilterMode
    case clearFilter
    case enterSpotlightSearch
    case togglePreview
    case toggleHiddenFiles
    case sortByName
    case sortBySize
    case sortByDate
    case sortBySelectionOrder
    case reverseSortOrder
    case refresh
    case openBookmarkSearch
    case addBookmark
    case openHistory
    case undo
    case openFile
    case openFileInFinder
    case toggleSidebar
    case toggleLeftPane
    case toggleRightPane
    case toggleSinglePane
    case equalizePaneWidths
    case matchOtherPaneDirectory
    case goToOtherPaneDirectory
    case toggleMediaMode
    case toggleFilesRecursive
    case toggleMediaRecursive
    case batchRename
    case syncPanesLeftToRight
    case syncPanesRightToLeft
    case launchClaude
    case launchCodex
    case toggleTerminalPanel
    case treeExpand
    case treeCollapse
    case togglePin
    case quit
}

extension KeyAction {
    var displayName: String {
        let spaced = rawValue.reduce(into: "") { partialResult, character in
            if character.isUppercase, !partialResult.isEmpty {
                partialResult.append(" ")
            }
            partialResult.append(character)
        }

        guard let first = spaced.first else {
            return rawValue
        }

        return first.uppercased() + spaced.dropFirst()
    }

    static func fromConfigName(_ rawName: String) -> KeyAction? {
        if let exact = KeyAction(rawValue: rawName) {
            return exact
        }

        return normalizedLookup[normalizedConfigKey(rawName)]
    }

    private static let normalizedLookup: [String: KeyAction] = {
        Dictionary(uniqueKeysWithValues: allCases.map { (normalizedConfigKey($0.rawValue), $0) })
    }()

    private static func normalizedConfigKey(_ value: String) -> String {
        value
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { Character($0).lowercased() }
            .joined()
    }
}
