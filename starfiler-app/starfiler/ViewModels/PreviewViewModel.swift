import Foundation
import Observation

@MainActor
@Observable
final class PreviewViewModel {
    struct State: Sendable {
        var selectedFileURL: URL?
        var currentDirectoryURL: URL?
        var siblingImageURLs: [URL]
        var showHiddenFiles: Bool
        var recursiveEnabled: Bool

        static let `default` = State(
            selectedFileURL: nil,
            currentDirectoryURL: nil,
            siblingImageURLs: [],
            showHiddenFiles: false,
            recursiveEnabled: false
        )
    }

    private(set) var state: State {
        didSet {
            onStateChanged?(state)
        }
    }

    var onStateChanged: ((State) -> Void)?
    var onRecursiveEnabledChanged: ((Bool) -> Void)?

    init(state: State = .default) {
        self.state = state
    }

    func updateContext(
        selectedItem: FileItem?,
        currentDirectoryURL: URL,
        displayedItems: [FileItem],
        showHiddenFiles: Bool
    ) {
        let selectedFileURL: URL?
        if let selectedItem, selectedItem.isDirectory, !selectedItem.isPackage {
            selectedFileURL = nil
        } else {
            selectedFileURL = selectedItem?.url
        }

        let siblingImageURLs = displayedItems.compactMap { item -> URL? in
            if item.isDirectory && !item.isPackage {
                return nil
            }
            return item.url.isImageFile ? item.url : nil
        }

        state = State(
            selectedFileURL: selectedFileURL,
            currentDirectoryURL: currentDirectoryURL,
            siblingImageURLs: siblingImageURLs,
            showHiddenFiles: showHiddenFiles,
            recursiveEnabled: state.recursiveEnabled
        )
    }

    func setSelectedFileURL(_ url: URL?) {
        var updated = state
        updated.selectedFileURL = url
        state = updated
    }

    func setRecursiveEnabled(_ enabled: Bool) {
        guard state.recursiveEnabled != enabled else {
            return
        }
        var updated = state
        updated.recursiveEnabled = enabled
        state = updated
        onRecursiveEnabledChanged?(enabled)
    }
}
