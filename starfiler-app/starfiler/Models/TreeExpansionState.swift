import Foundation

struct TreeExpansionState: Sendable {
    private(set) var expandedURLs: Set<URL> = []
    private(set) var childrenByParent: [URL: [FileItem]] = [:]

    mutating func expand(_ url: URL, children: [FileItem]) {
        expandedURLs.insert(url)
        childrenByParent[url] = children
    }

    mutating func collapse(_ url: URL) {
        expandedURLs.remove(url)
        let directChildren = childrenByParent.removeValue(forKey: url) ?? []
        for child in directChildren where child.isDirectory && !child.isPackage {
            collapse(child.url)
        }
    }

    func isExpanded(_ url: URL) -> Bool {
        expandedURLs.contains(url)
    }

    mutating func clear() {
        expandedURLs.removeAll()
        childrenByParent.removeAll()
    }

    mutating func updateChildren(for url: URL, children: [FileItem]) {
        guard expandedURLs.contains(url) else {
            return
        }
        childrenByParent[url] = children
    }
}
