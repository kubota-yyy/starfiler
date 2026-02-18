import Foundation
import Observation

@MainActor
@Observable
final class PreviewViewModel {
    struct State: Sendable, Equatable {
        var selectedFileURL: URL?
        var currentDirectoryURL: URL?
        var siblingMediaURLs: [URL]

        static let `default` = State(
            selectedFileURL: nil,
            currentDirectoryURL: nil,
            siblingMediaURLs: []
        )
    }

    private(set) var state: State {
        didSet {
            onStateChanged?(state)
        }
    }

    var onStateChanged: ((State) -> Void)?

    init(state: State = .default) {
        self.state = state
    }

    func updateContext(
        selectedItem: FileItem?,
        currentDirectoryURL: URL,
        displayedItems: [FileItem]
    ) {
        let selectedFileURL = normalizedPreviewableURL(from: selectedItem)

        let siblingMediaURLs = displayedItems.compactMap { item -> URL? in
            if item.isDirectory && !item.isPackage {
                return nil
            }
            return item.url.isMediaFile ? item.url : nil
        }

        let nextState = State(
            selectedFileURL: selectedFileURL,
            currentDirectoryURL: currentDirectoryURL,
            siblingMediaURLs: siblingMediaURLs
        )

        guard state != nextState else {
            return
        }

        state = nextState
    }

    func updateSelection(selectedItem: FileItem?) {
        let selectedFileURL = normalizedPreviewableURL(from: selectedItem)
        let normalizedCurrent = state.selectedFileURL?.standardizedFileURL
        let normalizedNext = selectedFileURL?.standardizedFileURL
        guard normalizedCurrent != normalizedNext else {
            return
        }

        var updated = state
        updated.selectedFileURL = selectedFileURL
        state = updated
    }

    func setSelectedFileURL(_ url: URL?) {
        let normalizedCurrent = state.selectedFileURL?.standardizedFileURL
        let normalizedNext = url?.standardizedFileURL
        guard normalizedCurrent != normalizedNext else {
            return
        }

        var updated = state
        updated.selectedFileURL = url
        state = updated
    }

    private func normalizedPreviewableURL(from selectedItem: FileItem?) -> URL? {
        if let selectedItem, selectedItem.isDirectory, !selectedItem.isPackage {
            return nil
        }
        return selectedItem?.url.standardizedFileURL
    }
}
