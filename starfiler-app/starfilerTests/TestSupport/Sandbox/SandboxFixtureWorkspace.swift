import Foundation

final class SandboxFixtureWorkspace {
    let rootURL: URL

    private let fileManager: FileManager
    private let workspaceDirectoryURL: URL

    init(fixtureVersion: String = "v1", fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        let fixtureURL = Self.fixtureURL(version: fixtureVersion)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fixtureURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(
                domain: "SandboxFixtureWorkspace",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Fixture directory not found: \(fixtureURL.path)"]
            )
        }

        let tempParent = fileManager.temporaryDirectory
            .appendingPathComponent("starfiler-sandbox-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempParent, withIntermediateDirectories: true)

        let destinationURL = tempParent.appendingPathComponent("workspace", isDirectory: true)
        try fileManager.copyItem(at: fixtureURL, to: destinationURL)

        self.workspaceDirectoryURL = tempParent
        self.rootURL = destinationURL
    }

    deinit {
        try? fileManager.removeItem(at: workspaceDirectoryURL)
    }

    func url(_ relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
    }

    static func fixtureURL(version: String = "v1") -> URL {
        let testsRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Sandbox
            .deletingLastPathComponent() // TestSupport
            .deletingLastPathComponent() // starfilerTests

        return testsRoot
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Sandbox", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
            .standardizedFileURL
    }
}
