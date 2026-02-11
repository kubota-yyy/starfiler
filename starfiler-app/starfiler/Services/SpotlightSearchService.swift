import Foundation

protocol SpotlightSearching: AnyObject {
    @MainActor func search(
        query: String,
        scope: SpotlightSearchScope,
        currentDirectory: URL
    ) -> AsyncStream<[FileItem]>
    func cancel()
}

@MainActor
final class SpotlightSearchService: NSObject, SpotlightSearching {
    private var metadataQuery: NSMetadataQuery?
    private var continuation: AsyncStream<[FileItem]>.Continuation?
    private var observers: [NSObjectProtocol] = []

    func search(
        query: String,
        scope: SpotlightSearchScope,
        currentDirectory: URL
    ) -> AsyncStream<[FileItem]> {
        cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.yield([])
                continuation.finish()
                return
            }

            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cancel()
                }
            }

            let queryObject = NSMetadataQuery()
            queryObject.searchScopes = Self.metadataSearchScopes(for: scope, currentDirectory: currentDirectory)
            queryObject.valueListAttributes = [
                NSMetadataItemURLKey,
                NSMetadataItemContentModificationDateKey,
                NSMetadataItemFSSizeKey
            ]
            queryObject.predicate = NSPredicate(
                format: "%K CONTAINS[cd] %@",
                NSMetadataItemDisplayNameKey,
                trimmed
            )
            queryObject.sortDescriptors = [
                NSSortDescriptor(key: NSMetadataItemDisplayNameKey, ascending: true)
            ]

            self.metadataQuery = queryObject
            self.installObservers(for: queryObject)
            queryObject.start()
        }
    }

    func cancel() {
        metadataQuery?.stop()
        metadataQuery = nil

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        continuation?.finish()
        continuation = nil
    }

    private func installObservers(for query: NSMetadataQuery) {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] _ in
                self?.publishResults(from: query)
            }
        )

        observers.append(
            center.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: .main
            ) { [weak self] _ in
                self?.publishResults(from: query)
            }
        )
    }

    private func publishResults(from query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        let items: [FileItem] = query.results.compactMap { result in
            guard let item = result as? NSMetadataItem else {
                return nil
            }

            let url: URL?
            if let directURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                url = directURL
            } else if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                url = URL(fileURLWithPath: path)
            } else {
                url = nil
            }

            guard let resolvedURL = url?.standardizedFileURL else {
                return nil
            }

            let resourceValues = try? resolvedURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .isHiddenKey,
                .isSymbolicLinkKey,
                .isPackageKey,
                .nameKey
            ])

            let fileSizeValue = item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
            let modifiedDate = item.value(forAttribute: NSMetadataItemContentModificationDateKey) as? Date

            return FileItem(
                url: resolvedURL,
                name: resourceValues?.name ?? resolvedURL.lastPathComponent,
                isDirectory: resourceValues?.isDirectory ?? false,
                size: fileSizeValue?.int64Value,
                dateModified: modifiedDate,
                isHidden: resourceValues?.isHidden ?? false,
                isSymlink: resourceValues?.isSymbolicLink ?? false,
                isPackage: resourceValues?.isPackage ?? false
            )
        }

        continuation?.yield(items)
    }

    private static func metadataSearchScopes(
        for scope: SpotlightSearchScope,
        currentDirectory: URL
    ) -> [Any] {
        switch scope {
        case .currentDirectory:
            return [currentDirectory.standardizedFileURL.path]
        case .userHome:
            return [NSMetadataQueryUserHomeScope]
        case .localComputer:
            return [NSMetadataQueryIndexedLocalComputerScope]
        }
    }
}
