import Foundation
@testable import Starfiler

final class MockFileSystemService: FileSystemProviding {
    // MARK: - contentsOfDirectory

    var contentsOfDirectoryResult: Result<[FileItem], Error> = .success([])
    private(set) var contentsOfDirectoryCallCount = 0
    private(set) var contentsOfDirectoryCapturedURLs: [URL] = []

    func contentsOfDirectory(at url: URL) async throws -> [FileItem] {
        contentsOfDirectoryCallCount += 1
        contentsOfDirectoryCapturedURLs.append(url)
        return try contentsOfDirectoryResult.get()
    }

    // MARK: - mediaItems

    var mediaItemsResult: Result<[FileItem], Error> = .success([])
    private(set) var mediaItemsCallCount = 0
    private(set) var mediaItemsCapturedArgs: [(directory: URL, recursive: Bool, includeHiddenFiles: Bool)] = []

    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) async throws -> [FileItem] {
        mediaItemsCallCount += 1
        mediaItemsCapturedArgs.append((directory, recursive, includeHiddenFiles))
        return try mediaItemsResult.get()
    }
}
