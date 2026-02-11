import Foundation
import Observation

@MainActor
@Observable
final class PreviewViewModel {
    var currentURL: URL? {
        didSet {
            onCurrentURLChanged?(currentURL)
        }
    }

    var onCurrentURLChanged: ((URL?) -> Void)?

    init(currentURL: URL? = nil) {
        self.currentURL = currentURL
    }
}
