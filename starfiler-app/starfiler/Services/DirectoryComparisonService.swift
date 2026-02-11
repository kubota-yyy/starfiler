import Foundation

protocol DirectoryComparing: Sendable {
    func compare(
        leftDirectory: URL,
        rightDirectory: URL,
        direction: SyncDirection,
        excludeRules: [SyncExcludeRule],
        progress: @escaping @Sendable (_ scanned: Int) -> Void
    ) async throws -> [SyncItem]
}

struct DirectoryComparisonService: DirectoryComparing {
    private struct FileMetadata: Sendable {
        let url: URL
        let isDirectory: Bool
        let size: Int64?
        let dateModified: Date?
    }

    func compare(
        leftDirectory: URL,
        rightDirectory: URL,
        direction: SyncDirection,
        excludeRules: [SyncExcludeRule],
        progress: @escaping @Sendable (_ scanned: Int) -> Void
    ) async throws -> [SyncItem] {
        let leftTree = try enumerateDirectory(leftDirectory)
        progress(leftTree.count)

        try Task.checkCancellation()

        let rightTree = try enumerateDirectory(rightDirectory)
        progress(leftTree.count + rightTree.count)

        try Task.checkCancellation()

        let allPaths = Set(leftTree.keys).union(Set(rightTree.keys))
        let enabledPatterns = excludeRules.filter(\.isEnabled).map(\.pattern)

        var items: [SyncItem] = []
        items.reserveCapacity(allPaths.count)

        for relativePath in allPaths.sorted() {
            try Task.checkCancellation()

            let leftMeta = leftTree[relativePath]
            let rightMeta = rightTree[relativePath]

            let status: SyncItemStatus
            if matchesExcludeRules(relativePath, patterns: enabledPatterns) {
                status = .excluded
            } else {
                status = determineStatus(left: leftMeta, right: rightMeta)
            }

            let action = defaultAction(for: status, direction: direction)

            let item = SyncItem(
                relativePath: relativePath,
                isDirectory: leftMeta?.isDirectory ?? rightMeta?.isDirectory ?? false,
                leftURL: leftMeta?.url,
                rightURL: rightMeta?.url,
                leftSize: leftMeta?.size,
                rightSize: rightMeta?.size,
                leftDate: leftMeta?.dateModified,
                rightDate: rightMeta?.dateModified,
                status: status,
                action: action
            )
            items.append(item)
        }

        // Sort: directories first, then alphabetical
        items.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.relativePath.localizedStandardCompare(b.relativePath) == .orderedAscending
        }

        return items
    }

    private func enumerateDirectory(_ baseURL: URL) throws -> [String: FileMetadata] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]

        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return [:]
        }

        var tree: [String: FileMetadata] = [:]
        let basePath = baseURL.standardizedFileURL.path

        for case let url as URL in enumerator {
            let standardized = url.standardizedFileURL
            let fullPath = standardized.path

            guard fullPath.hasPrefix(basePath) else { continue }
            let relativePath = String(fullPath.dropFirst(basePath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            guard !relativePath.isEmpty else { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            let isDir = values?.isDirectory ?? false
            let size = isDir ? nil : (values?.fileSize).map(Int64.init)
            let date = values?.contentModificationDate

            tree[relativePath] = FileMetadata(
                url: standardized,
                isDirectory: isDir,
                size: size,
                dateModified: date
            )
        }

        return tree
    }

    private func matchesExcludeRules(_ relativePath: String, patterns: [String]) -> Bool {
        let fileName = (relativePath as NSString).lastPathComponent
        let pathComponents = relativePath.split(separator: "/").map(String.init)

        for pattern in patterns {
            // Match against filename
            if fnmatch(pattern, fileName, 0) == 0 {
                return true
            }
            // Match against each path component
            for component in pathComponents {
                if fnmatch(pattern, component, 0) == 0 {
                    return true
                }
            }
            // Match against full relative path
            if fnmatch(pattern, relativePath, 0) == 0 {
                return true
            }
        }
        return false
    }

    private func determineStatus(left: FileMetadata?, right: FileMetadata?) -> SyncItemStatus {
        guard let left else { return .rightOnly }
        guard let right else { return .leftOnly }

        // Both exist
        let sameSize = left.size == right.size

        if let leftDate = left.dateModified, let rightDate = right.dateModified {
            let timeDiff = leftDate.timeIntervalSince(rightDate)
            if sameSize && abs(timeDiff) < 2.0 {
                return .identical
            }
            if timeDiff > 2.0 {
                return .leftNewer
            }
            if timeDiff < -2.0 {
                return .rightNewer
            }
        }

        if sameSize {
            return .identical
        }

        return .conflict
    }

    private func defaultAction(for status: SyncItemStatus, direction: SyncDirection) -> SyncItemAction {
        switch (status, direction) {
        case (.identical, _), (.excluded, _):
            return .skip

        case (.leftOnly, .leftToRight):
            return .copyToRight
        case (.leftOnly, .rightToLeft):
            return .skip
        case (.leftOnly, .bidirectional):
            return .copyToRight

        case (.rightOnly, .leftToRight):
            return .skip
        case (.rightOnly, .rightToLeft):
            return .copyToLeft
        case (.rightOnly, .bidirectional):
            return .copyToLeft

        case (.leftNewer, .leftToRight):
            return .copyToRight
        case (.leftNewer, .rightToLeft):
            return .skip
        case (.leftNewer, .bidirectional):
            return .copyToRight

        case (.rightNewer, .leftToRight):
            return .skip
        case (.rightNewer, .rightToLeft):
            return .copyToLeft
        case (.rightNewer, .bidirectional):
            return .copyToLeft

        case (.conflict, .leftToRight):
            return .copyToRight
        case (.conflict, .rightToLeft):
            return .copyToLeft
        case (.conflict, .bidirectional):
            return .skip
        }
    }
}
