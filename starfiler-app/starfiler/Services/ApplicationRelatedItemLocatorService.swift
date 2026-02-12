import Foundation

protocol ApplicationRelatedItemLocating {
    func relatedItems(forApplicationsAt appURLs: [URL]) -> [ApplicationRelatedItem]
}

struct ApplicationRelatedItem: Hashable {
    let appURL: URL
    let url: URL
    let category: String
}

struct ApplicationRelatedItemLocatorService: ApplicationRelatedItemLocating {
    private struct AppMetadata {
        let bundleIdentifier: String?
        let displayNames: [String]
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func relatedItems(forApplicationsAt appURLs: [URL]) -> [ApplicationRelatedItem] {
        let normalizedApps = appURLs
            .map(\.standardizedFileURL)
            .filter { Self.isApplicationBundleUnderApplications($0) }

        guard !normalizedApps.isEmpty else {
            return []
        }

        var seenPaths: Set<String> = []
        var related: [ApplicationRelatedItem] = []
        let homeDirectory = UserPaths.homeDirectoryURL
        let libraryDirectory = homeDirectory.appendingPathComponent("Library", isDirectory: true)

        for appURL in normalizedApps {
            let metadata = loadMetadata(for: appURL)

            if let bundleIdentifier = metadata.bundleIdentifier {
                let exactCandidates: [(path: String, category: String)] = [
                    ("Application Support/\(bundleIdentifier)", "Application Support"),
                    ("Caches/\(bundleIdentifier)", "Cache"),
                    ("Preferences/\(bundleIdentifier).plist", "Preferences"),
                    ("Saved Application State/\(bundleIdentifier).savedState", "Saved State"),
                    ("HTTPStorages/\(bundleIdentifier)", "HTTP Storage"),
                    ("WebKit/\(bundleIdentifier)", "WebKit Data"),
                    ("Containers/\(bundleIdentifier)", "Container"),
                    ("Application Scripts/\(bundleIdentifier)", "Application Scripts"),
                    ("Logs/\(bundleIdentifier)", "Logs")
                ]

                for candidate in exactCandidates {
                    addIfExists(
                        at: libraryDirectory.appendingPathComponent(candidate.path),
                        appURL: appURL,
                        category: candidate.category,
                        seenPaths: &seenPaths,
                        result: &related
                    )
                }

                collectPrefixedEntries(
                    in: libraryDirectory.appendingPathComponent("Preferences", isDirectory: true),
                    prefix: bundleIdentifier,
                    appURL: appURL,
                    category: "Preferences",
                    seenPaths: &seenPaths,
                    result: &related
                )

                collectMatchingEntries(
                    in: libraryDirectory.appendingPathComponent("Group Containers", isDirectory: true),
                    matcher: { name in
                        let normalizedName = name.lowercased()
                        let normalizedBundleID = bundleIdentifier.lowercased()
                        return normalizedName == normalizedBundleID || normalizedName.hasSuffix(".\(normalizedBundleID)")
                    },
                    appURL: appURL,
                    category: "Group Container",
                    seenPaths: &seenPaths,
                    result: &related
                )
            }

            for displayName in metadata.displayNames {
                guard !displayName.isEmpty else {
                    continue
                }

                let nameCandidates: [(path: String, category: String)] = [
                    ("Application Support/\(displayName)", "Application Support"),
                    ("Caches/\(displayName)", "Cache"),
                    ("Logs/\(displayName)", "Logs"),
                    ("Saved Application State/\(displayName).savedState", "Saved State")
                ]

                for candidate in nameCandidates {
                    addIfExists(
                        at: libraryDirectory.appendingPathComponent(candidate.path),
                        appURL: appURL,
                        category: candidate.category,
                        seenPaths: &seenPaths,
                        result: &related
                    )
                }
            }
        }

        return related.sorted { lhs, rhs in
            lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
        }
    }

    private func loadMetadata(for appURL: URL) -> AppMetadata {
        let infoPlistURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        guard
            let data = try? Data(contentsOf: infoPlistURL),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = raw as? [String: Any]
        else {
            let fallbackName = appURL.deletingPathExtension().lastPathComponent
            return AppMetadata(bundleIdentifier: nil, displayNames: [fallbackName])
        }

        let bundleIdentifier = (dictionary["CFBundleIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameValues = [
            dictionary["CFBundleDisplayName"] as? String,
            dictionary["CFBundleName"] as? String,
            appURL.deletingPathExtension().lastPathComponent
        ]

        var seen: Set<String> = []
        let names = nameValues
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }

        return AppMetadata(bundleIdentifier: bundleIdentifier?.isEmpty == true ? nil : bundleIdentifier, displayNames: names)
    }

    private func addIfExists(
        at url: URL,
        appURL: URL,
        category: String,
        seenPaths: inout Set<String>,
        result: inout [ApplicationRelatedItem]
    ) {
        let normalizedURL = url.standardizedFileURL
        let path = normalizedURL.path
        guard !seenPaths.contains(path), fileManager.fileExists(atPath: path) else {
            return
        }

        seenPaths.insert(path)
        result.append(ApplicationRelatedItem(appURL: appURL, url: normalizedURL, category: category))
    }

    private func collectPrefixedEntries(
        in directoryURL: URL,
        prefix: String,
        appURL: URL,
        category: String,
        seenPaths: inout Set<String>,
        result: inout [ApplicationRelatedItem]
    ) {
        let entries = contentsOfDirectory(at: directoryURL)
        guard !entries.isEmpty else {
            return
        }

        let lowercasedPrefix = prefix.lowercased()

        for entry in entries {
            let fileName = entry.lastPathComponent.lowercased()
            guard fileName.hasPrefix(lowercasedPrefix) else {
                continue
            }

            addIfExists(
                at: entry,
                appURL: appURL,
                category: category,
                seenPaths: &seenPaths,
                result: &result
            )
        }
    }

    private func collectMatchingEntries(
        in directoryURL: URL,
        matcher: (String) -> Bool,
        appURL: URL,
        category: String,
        seenPaths: inout Set<String>,
        result: inout [ApplicationRelatedItem]
    ) {
        let entries = contentsOfDirectory(at: directoryURL)
        guard !entries.isEmpty else {
            return
        }

        for entry in entries {
            let fileName = entry.lastPathComponent
            guard matcher(fileName) else {
                continue
            }

            addIfExists(
                at: entry,
                appURL: appURL,
                category: category,
                seenPaths: &seenPaths,
                result: &result
            )
        }
    }

    private func contentsOfDirectory(at url: URL) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
    }

    private static func isApplicationBundleUnderApplications(_ url: URL) -> Bool {
        let normalized = url.standardizedFileURL
        guard normalized.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
            return false
        }

        let path = normalized.path
        return path.hasPrefix("/Applications/")
    }
}
