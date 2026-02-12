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
        let timeline = backStack + [current] + reversedForward
        let currentIndex = backStack.count
        guard position >= 0, position < timeline.count, position != currentIndex else {
            return nil
        }
        let destination = timeline[position]
        backStack = Array(timeline[0..<position])
        forwardStack = Array(timeline[(position + 1)...].reversed())
        return destination
    }
}
