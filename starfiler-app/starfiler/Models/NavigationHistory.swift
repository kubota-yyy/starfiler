import Foundation

struct NavigationHistory: Hashable, Sendable {
    static let entryLimit = 100

    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    init(backStack: [URL] = [], forwardStack: [URL] = []) {
        self.backStack = Self.normalizedURLs(backStack)
        self.forwardStack = Self.normalizedURLs(forwardStack)
    }

    mutating func push(_ current: URL) {
        let normalizedCurrent = current.standardizedFileURL
        if backStack.last != normalizedCurrent {
            backStack.append(normalizedCurrent)
            trimBackStackIfNeeded()
        }
        forwardStack.removeAll()
    }

    mutating func goBack(from current: URL) -> URL? {
        guard let destination = backStack.popLast() else {
            return nil
        }
        let normalizedCurrent = current.standardizedFileURL
        if forwardStack.last != normalizedCurrent {
            forwardStack.append(normalizedCurrent)
            trimForwardStackIfNeeded()
        }
        return destination
    }

    mutating func goForward(from current: URL) -> URL? {
        guard let destination = forwardStack.popLast() else {
            return nil
        }
        let normalizedCurrent = current.standardizedFileURL
        if backStack.last != normalizedCurrent {
            backStack.append(normalizedCurrent)
            trimBackStackIfNeeded()
        }
        return destination
    }

    struct TimelineEntry: Hashable, Sendable {
        let url: URL
        let isCurrentPosition: Bool
        let timelineIndex: Int
    }

    func timeline(current: URL) -> [TimelineEntry] {
        let reversedForward = Array(forwardStack.reversed())
        let all = backStack + [current] + reversedForward
        let currentIndex = backStack.count
        return all.enumerated().map { index, url in
            TimelineEntry(url: url, isCurrentPosition: index == currentIndex, timelineIndex: index)
        }
    }

    mutating func jumpToTimelinePosition(_ position: Int, from current: URL) -> URL? {
        let reversedForward = Array(forwardStack.reversed())
        let normalizedCurrent = current.standardizedFileURL
        let timeline = backStack + [normalizedCurrent] + reversedForward
        let currentIndex = backStack.count
        guard position >= 0, position < timeline.count, position != currentIndex else {
            return nil
        }
        let destination = timeline[position]
        backStack = Array(timeline[0..<position])
        forwardStack = Array(timeline[(position + 1)...].reversed())
        trimBackStackIfNeeded()
        trimForwardStackIfNeeded()
        return destination
    }

    private mutating func trimBackStackIfNeeded() {
        guard backStack.count > Self.entryLimit else {
            return
        }
        backStack.removeFirst(backStack.count - Self.entryLimit)
    }

    private mutating func trimForwardStackIfNeeded() {
        guard forwardStack.count > Self.entryLimit else {
            return
        }
        forwardStack.removeFirst(forwardStack.count - Self.entryLimit)
    }

    private static func normalizedURLs(_ urls: [URL]) -> [URL] {
        guard !urls.isEmpty else {
            return []
        }

        let normalized = urls.map(\.standardizedFileURL)
        if normalized.count <= entryLimit {
            return normalized
        }

        return Array(normalized.suffix(entryLimit))
    }
}
