import XCTest
@testable import Starfiler

final class FileSystemServiceIntegrationTests: XCTestCase {
    func testContentsOfDirectoryIncludesHiddenAndPackageFlags() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileSystemService()

        let items = try await sut.contentsOfDirectory(at: workspace.url("left"))

        XCTAssertTrue(items.contains(where: { $0.name == ".hidden.txt" && $0.isHidden }))
        XCTAssertTrue(items.contains(where: { $0.name == "Sample.app" && $0.isPackage }))
        XCTAssertTrue(items.contains(where: { $0.name == "docs" && $0.isDirectory }))
    }

    func testRecursiveContentsRespectsHiddenFlagAndSkipsPackageDescendants() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileSystemService()

        let withoutHidden = try await sut.recursiveContentsOfDirectory(
            at: workspace.url("left"),
            includeHiddenFiles: false
        )
        let withHidden = try await sut.recursiveContentsOfDirectory(
            at: workspace.url("left"),
            includeHiddenFiles: true
        )

        XCTAssertFalse(withoutHidden.contains(where: { $0.name == ".hidden.txt" }))
        XCTAssertTrue(withHidden.contains(where: { $0.name == ".hidden.txt" }))
        XCTAssertFalse(withHidden.contains(where: { $0.url.path.contains("Sample.app/Contents") }))
    }

    func testMediaItemsFiltersByMediaExtensions() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileSystemService()

        let nonRecursive = try await sut.mediaItems(
            in: workspace.url("left/media"),
            recursive: false,
            includeHiddenFiles: true
        )

        XCTAssertEqual(Set(nonRecursive.map(\.name)), Set(["photo.jpg", "video.mp4"]))
    }

    func testMediaItemsRecursiveFindsNestedMediaFiles() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let nestedDir = workspace.url("left/media/nested")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try "nested media".write(to: nestedDir.appendingPathComponent("nested.png"), atomically: true, encoding: .utf8)

        let sut = FileSystemService()
        let recursive = try await sut.mediaItems(
            in: workspace.url("left"),
            recursive: true,
            includeHiddenFiles: true
        )

        XCTAssertTrue(recursive.contains(where: { $0.name == "nested.png" }))
    }

    func testMediaItemsDoesNotTreatTypeScriptAsMedia() async throws {
        let workspace = try SandboxFixtureWorkspace()
        try "const answer: number = 42".write(
            to: workspace.url("left/media/script.ts"),
            atomically: true,
            encoding: .utf8
        )

        let sut = FileSystemService()
        let nonRecursive = try await sut.mediaItems(
            in: workspace.url("left/media"),
            recursive: false,
            includeHiddenFiles: true
        )

        XCTAssertEqual(Set(nonRecursive.map(\.name)), Set(["photo.jpg", "video.mp4"]))
        XCTAssertFalse(nonRecursive.contains(where: { $0.name == "script.ts" }))
    }
}
