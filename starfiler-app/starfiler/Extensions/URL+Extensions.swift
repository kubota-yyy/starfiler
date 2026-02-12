import Foundation
import Darwin
import UniformTypeIdentifiers

enum UserPaths {
    static var homeDirectoryURL: URL {
        let userName = NSUserName()
        let candidates: [String?] = [
            NSHomeDirectoryForUser(userName),
            "/Users/\(userName)",
            homeDirectoryFromPasswordDB(),
            FileManager.default.homeDirectoryForCurrentUser.path,
            NSHomeDirectory()
        ]

        for candidate in candidates {
            guard let candidatePath = candidate, !candidatePath.isEmpty else {
                continue
            }

            let normalizedPath = normalizedHomePath(from: candidatePath)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: normalizedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: normalizedPath, isDirectory: true).standardizedFileURL
            }
        }

        return URL(fileURLWithPath: "/Users/\(userName)", isDirectory: true).standardizedFileURL
    }

    static var homeDirectoryPath: String {
        homeDirectoryURL.path
    }

    static func resolveBookmarkPath(_ rawPath: String, fileManager: FileManager = .default) -> String {
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path

        if let migratedDropboxPath = resolveDropboxPath(from: standardizedPath, fileManager: fileManager) {
            return migratedDropboxPath
        }

        if fileManager.fileExists(atPath: standardizedPath) {
            return standardizedPath
        }

        return standardizedPath
    }

    private static func homeDirectoryFromPasswordDB() -> String? {
        guard let pw = getpwuid(getuid()), let homePtr = pw.pointee.pw_dir else {
            return nil
        }
        let home = String(cString: homePtr)
        return home.isEmpty ? nil : home
    }

    private static func normalizedHomePath(from rawPath: String) -> String {
        let standardizedPath = URL(fileURLWithPath: rawPath, isDirectory: true)
            .standardizedFileURL
            .path

        let marker = "/Library/Containers/"
        guard let markerRange = standardizedPath.range(of: marker) else {
            return standardizedPath
        }

        let unsandboxedPath = String(standardizedPath[..<markerRange.lowerBound])
        return unsandboxedPath.isEmpty ? standardizedPath : unsandboxedPath
    }

    private static func resolveDropboxPath(from path: String, fileManager: FileManager) -> String? {
        let suffix = dropboxRelativeSuffix(from: path)
        guard let suffix else {
            return nil
        }

        for root in discoverDropboxRoots(fileManager: fileManager) {
            let candidatePath = suffix.isEmpty ? root : root + suffix
            if fileManager.fileExists(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath).standardizedFileURL.path
            }
        }

        return nil
    }

    private static func dropboxRelativeSuffix(from path: String) -> String? {
        let legacyRoot = homeDirectoryPath + "/Dropbox"
        if path == legacyRoot {
            return ""
        }
        if path.hasPrefix(legacyRoot + "/") {
            return String(path.dropFirst(legacyRoot.count))
        }

        let cloudStorageRoot = homeDirectoryPath + "/Library/CloudStorage/"
        guard path.hasPrefix(cloudStorageRoot) else {
            return nil
        }

        let remainder = String(path.dropFirst(cloudStorageRoot.count))
        let parts = remainder.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard let provider = parts.first, provider.lowercased().hasPrefix("dropbox") else {
            return nil
        }

        guard parts.count > 1 else {
            return ""
        }
        return "/" + parts[1]
    }

    private static func discoverDropboxRoots(fileManager: FileManager) -> [String] {
        var cloudRoots: [String] = []

        let cloudStorageURL = URL(fileURLWithPath: homeDirectoryPath + "/Library/CloudStorage", isDirectory: true)
        if let candidates = try? fileManager.contentsOfDirectory(
            at: cloudStorageURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for candidate in candidates where candidate.lastPathComponent.lowercased().hasPrefix("dropbox") && candidate.isDirectory {
                cloudRoots.append(candidate.standardizedFileURL.path)
            }
        }

        var roots = cloudRoots
        if roots.isEmpty {
            let legacyRoot = homeDirectoryPath + "/Dropbox"
            var isLegacyDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: legacyRoot, isDirectory: &isLegacyDirectory), isLegacyDirectory.boolValue {
                roots.append(URL(fileURLWithPath: legacyRoot, isDirectory: true).standardizedFileURL.path)
            }
        }

        var seen: Set<String> = []
        var uniqueRoots: [String] = []
        for root in roots where !seen.contains(root) {
            seen.insert(root)
            uniqueRoots.append(root)
        }
        return uniqueRoots.sorted { lhs, rhs in
            let lhsName = URL(fileURLWithPath: lhs).lastPathComponent.lowercased()
            let rhsName = URL(fileURLWithPath: rhs).lastPathComponent.lowercased()
            if lhsName == rhsName {
                return lhs < rhs
            }
            if lhsName == "dropbox" {
                return true
            }
            if rhsName == "dropbox" {
                return false
            }
            return lhsName < rhsName
        }
    }
}

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    var isPackage: Bool {
        (try? resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
    }

    var displayName: String {
        FileManager.default.displayName(atPath: path)
    }

    var isImageFile: Bool {
        if hasDirectoryPath {
            return false
        }

        if let type = (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType {
            return type.conforms(to: .image)
        }

        let lowercasedExtension = pathExtension.lowercased()
        guard !lowercasedExtension.isEmpty else {
            return false
        }

        if let type = UTType(filenameExtension: lowercasedExtension) {
            return type.conforms(to: .image)
        }

        let commonImageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "webp", "avif", "svg", "ico"
        ]
        return commonImageExtensions.contains(lowercasedExtension)
    }

    var isVideoFile: Bool {
        if hasDirectoryPath {
            return false
        }

        if let type = (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType {
            return type.conforms(to: .movie) || type.conforms(to: .video)
        }

        let lowercasedExtension = pathExtension.lowercased()
        guard !lowercasedExtension.isEmpty else {
            return false
        }

        if let type = UTType(filenameExtension: lowercasedExtension) {
            return type.conforms(to: .movie) || type.conforms(to: .video)
        }

        let commonVideoExtensions: Set<String> = [
            "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "mpg", "mpeg", "3gp", "ts", "m2ts"
        ]
        return commonVideoExtensions.contains(lowercasedExtension)
    }

    var isMediaFile: Bool {
        isImageFile || isVideoFile
    }
}
