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
