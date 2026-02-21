import Foundation

struct TreeExpansionState: Sendable {
    private(set) var expandedURLs: Set<URL> = []
    private(set) var childrenByParent: [URL: [FileItem]] = [:]

    mutating func expand(_ url: URL, children: [FileItem]) {
        let normalizedURL = normalize(url)
        expandedURLs.insert(normalizedURL)
        childrenByParent[normalizedURL] = children
    }

    mutating func collapse(_ url: URL) {
        let normalizedURL = normalize(url)
        expandedURLs.remove(normalizedURL)
        let directChildren = childrenByParent.removeValue(forKey: normalizedURL) ?? []
        for child in directChildren where child.isDirectory && !child.isPackage {
            collapse(child.url)
        }
    }

    func isExpanded(_ url: URL) -> Bool {
        expandedURLs.contains(normalize(url))
    }

    mutating func clear() {
        expandedURLs.removeAll()
        childrenByParent.removeAll()
    }

    mutating func updateChildren(for url: URL, children: [FileItem]) {
        let normalizedURL = normalize(url)
        guard expandedURLs.contains(normalizedURL) else {
            return
        }
        childrenByParent[normalizedURL] = children
    }

    func children(for parentURL: URL) -> [FileItem]? {
        childrenByParent[normalize(parentURL)]
    }

    private func normalize(_ url: URL) -> URL {
        url.standardizedFileURL
    }
}
