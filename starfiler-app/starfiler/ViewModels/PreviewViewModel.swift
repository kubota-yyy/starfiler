import Foundation
import Observation

@MainActor
@Observable
final class PreviewViewModel {
    struct State: Sendable {
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
        let selectedFileURL: URL?
        if let selectedItem, selectedItem.isDirectory, !selectedItem.isPackage {
            selectedFileURL = nil
        } else {
            selectedFileURL = selectedItem?.url
        }

        let siblingMediaURLs = displayedItems.compactMap { item -> URL? in
            if item.isDirectory && !item.isPackage {
                return nil
            }
            return item.url.isMediaFile ? item.url : nil
        }

        state = State(
            selectedFileURL: selectedFileURL,
            currentDirectoryURL: currentDirectoryURL,
            siblingMediaURLs: siblingMediaURLs
        )
    }

    func setSelectedFileURL(_ url: URL?) {
        var updated = state
        updated.selectedFileURL = url
        state = updated
    }
}
