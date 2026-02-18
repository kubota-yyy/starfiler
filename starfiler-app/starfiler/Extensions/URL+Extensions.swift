import Foundation
import Darwin

enum UserPaths {
    static var homeDirectoryURL: URL {
        let userName = NSUserName()
        let normalizedUserName = normalizedUserName(from: userName)
        var candidates: [String?] = [
            FileManager.default.homeDirectoryForCurrentUser.path,
            NSHomeDirectory(),
            homeDirectoryFromPasswordDB(),
            NSHomeDirectoryForUser(userName),
        ]

        if normalizedUserName != userName {
            candidates.append(NSHomeDirectoryForUser(normalizedUserName))
        }

        candidates.append("/Users/\(normalizedUserName)")
        if normalizedUserName != userName {
            candidates.append("/Users/\(userName)")
        }

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

        return URL(fileURLWithPath: "/Users/\(normalizedUserName)", isDirectory: true).standardizedFileURL
    }

    static var homeDirectoryPath: String {
        homeDirectoryURL.path
    }

    static var desktopDirectoryURL: URL {
        knownDirectoryURL(for: .desktopDirectory, fallbackComponent: "Desktop")
    }

    static var documentsDirectoryURL: URL {
        knownDirectoryURL(for: .documentDirectory, fallbackComponent: "Documents")
    }

    static var downloadsDirectoryURL: URL {
        knownDirectoryURL(for: .downloadsDirectory, fallbackComponent: "Downloads")
    }

    static var desktopDirectoryPath: String {
        desktopDirectoryURL.path
    }

    static var documentsDirectoryPath: String {
        documentsDirectoryURL.path
    }

    static var downloadsDirectoryPath: String {
        downloadsDirectoryURL.path
    }

    static func portableBookmarkPath(_ rawPath: String, fileManager: FileManager = .default) -> String {
        let resolvedPath = resolveBookmarkPath(rawPath, fileManager: fileManager)
        if resolvedPath == homeDirectoryPath {
            return "~"
        }
        if resolvedPath.hasPrefix(homeDirectoryPath + "/") {
            return "~" + String(resolvedPath.dropFirst(homeDirectoryPath.count))
        }
        return resolvedPath
    }

    static func resolveBookmarkPath(_ rawPath: String, fileManager: FileManager = .default) -> String {
        let expandedPath = expandedPathByResolvingHomeVariables(rawPath)
        var standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path

        if let relocatedPath = relocatedPathToCurrentHome(from: standardizedPath, fileManager: fileManager) {
            standardizedPath = relocatedPath
        }

        if let migratedDropboxPath = resolveDropboxPath(from: standardizedPath, fileManager: fileManager) {
            return migratedDropboxPath
        }

        return standardizedPath
    }

    private static func expandedPathByResolvingHomeVariables(_ rawPath: String) -> String {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return rawPath
        }

        let normalizedPath = normalizedHomeAliasPath(from: trimmedPath)

        let expandedHomePath: String
        if normalizedPath == "$HOME" || normalizedPath == "${HOME}" {
            expandedHomePath = homeDirectoryPath
        } else if normalizedPath.hasPrefix("$HOME/") {
            expandedHomePath = homeDirectoryPath + String(normalizedPath.dropFirst("$HOME".count))
        } else if normalizedPath.hasPrefix("${HOME}/") {
            expandedHomePath = homeDirectoryPath + String(normalizedPath.dropFirst("${HOME}".count))
        } else if isHomeRelativeShortcutPath(normalizedPath) {
            expandedHomePath = homeDirectoryPath + "/" + normalizedPath
        } else {
            expandedHomePath = normalizedPath
        }

        return (expandedHomePath as NSString).expandingTildeInPath
    }

    private static func normalizedHomeAliasPath(from path: String) -> String {
        let lowercasedPath = path.lowercased()
        if lowercasedPath == "home" {
            return "~"
        }

        let prefix = "home/"
        guard lowercasedPath.hasPrefix(prefix) else {
            return path
        }

        let suffixStart = path.index(path.startIndex, offsetBy: prefix.count)
        return "~/" + String(path[suffixStart...])
    }

    private static func isHomeRelativeShortcutPath(_ path: String) -> Bool {
        guard !path.isEmpty else {
            return false
        }

        if path.contains("://") {
            return false
        }

        if path.hasPrefix("/") || path.hasPrefix("~") || path.hasPrefix("$HOME") || path.hasPrefix("${HOME}") {
            return false
        }

        if path == "." || path == ".." || path.hasPrefix("./") || path.hasPrefix("../") {
            return false
        }

        return true
    }

    private static func relocatedPathToCurrentHome(from path: String, fileManager: FileManager) -> String? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardizedPath == homeDirectoryPath || standardizedPath.hasPrefix(homeDirectoryPath + "/") {
            return standardizedPath
        }

        let pathComponents = URL(fileURLWithPath: standardizedPath).pathComponents
        guard pathComponents.count >= 3,
              pathComponents[1] == "Users",
              pathComponents[2] != "Shared"
        else {
            return nil
        }

        var relocatedPath = homeDirectoryPath
        let suffixComponents = pathComponents.dropFirst(3)
        if !suffixComponents.isEmpty {
            relocatedPath += "/" + suffixComponents.joined(separator: "/")
        }

        let sourceExists = fileManager.fileExists(atPath: standardizedPath)
        guard !sourceExists else {
            return nil
        }

        return URL(fileURLWithPath: relocatedPath).standardizedFileURL.path
    }

    private static func homeDirectoryFromPasswordDB() -> String? {
        guard let pw = getpwuid(getuid()), let homePtr = pw.pointee.pw_dir else {
            return nil
        }
        let home = String(cString: homePtr)
        return home.isEmpty ? nil : home
    }

    private static func normalizedUserName(from rawUserName: String) -> String {
        let trimmedUserName = rawUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserName.isEmpty else {
            return rawUserName
        }

        guard let separator = trimmedUserName.firstIndex(of: "@"), separator > trimmedUserName.startIndex else {
            return trimmedUserName
        }

        let sanitized = String(trimmedUserName[..<separator])
        return sanitized.isEmpty ? trimmedUserName : sanitized
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

    private static func knownDirectoryURL(
        for directory: FileManager.SearchPathDirectory,
        fallbackComponent: String
    ) -> URL {
        if let resolvedURL = FileManager.default.urls(for: directory, in: .userDomainMask).first {
            return resolvedURL.standardizedFileURL
        }
        return homeDirectoryURL
            .appendingPathComponent(fallbackComponent, isDirectory: true)
            .standardizedFileURL
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
    private static let mediaImageExtensionWhitelist: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "avif", "svg", "ico"
    ]

    private static let mediaVideoExtensionWhitelist: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "mpg", "mpeg", "3gp", "m2ts"
    ]

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

        let lowercasedExtension = pathExtension.lowercased()
        guard !lowercasedExtension.isEmpty else {
            return false
        }

        return Self.mediaImageExtensionWhitelist.contains(lowercasedExtension)
    }

    var isVideoFile: Bool {
        if hasDirectoryPath {
            return false
        }

        let lowercasedExtension = pathExtension.lowercased()
        guard !lowercasedExtension.isEmpty else {
            return false
        }

        return Self.mediaVideoExtensionWhitelist.contains(lowercasedExtension)
    }

    var isMediaFile: Bool {
        isImageFile || isVideoFile
    }

    var isMarkdownFile: Bool {
        if hasDirectoryPath {
            return false
        }

        let lowercasedExtension = pathExtension.lowercased()
        guard !lowercasedExtension.isEmpty else {
            return false
        }

        let markdownExtensions: Set<String> = [
            "md", "markdown", "mdown", "mkd", "mkdn"
        ]
        return markdownExtensions.contains(lowercasedExtension)
    }
}
