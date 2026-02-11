import Foundation

struct NavigationHistory: Hashable, Sendable {
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    mutating func push(_ current: URL) {
        if backStack.last != current {
            backStack.append(current)
        }
        forwardStack.removeAll()
    }

    mutating func goBack(from current: URL) -> URL? {
        guard let destination = backStack.popLast() else {
            return nil
        }
        if forwardStack.last != current {
            forwardStack.append(current)
        }
        return destination
    }

    mutating func goForward(from current: URL) -> URL? {
        guard let destination = forwardStack.popLast() else {
            return nil
        }
        if backStack.last != current {
            backStack.append(current)
        }
        return destination
    }
}
