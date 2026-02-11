import Foundation

protocol BatchRenameComputing: Sendable {
    func computeNewNames(
        files: [FileItem],
        rules: [BatchRenameRule],
        allDirectoryFiles: [FileItem]
    ) -> [BatchRenameEntry]
}

struct BatchRenameService: BatchRenameComputing {
    func computeNewNames(
        files: [FileItem],
        rules: [BatchRenameRule],
        allDirectoryFiles: [FileItem]
    ) -> [BatchRenameEntry] {
        guard !files.isEmpty else {
            return []
        }

        var entries: [BatchRenameEntry] = []
        entries.reserveCapacity(files.count)

        let batchURLs = Set(files.map(\.url))

        for (index, file) in files.enumerated() {
            let result = applyRules(
                rules,
                to: file,
                index: index,
                totalCount: files.count
            )

            switch result {
            case .success(let newName):
                entries.append(BatchRenameEntry(
                    originalURL: file.url,
                    originalName: file.name,
                    newName: newName,
                    hasConflict: false,
                    errorMessage: nil
                ))
            case .failure(let error):
                entries.append(BatchRenameEntry(
                    originalURL: file.url,
                    originalName: file.name,
                    newName: file.name,
                    hasConflict: true,
                    errorMessage: error.localizedDescription
                ))
            }
        }

        markConflicts(&entries, batchURLs: batchURLs, allDirectoryFiles: allDirectoryFiles)

        return entries
    }

    private func applyRules(
        _ rules: [BatchRenameRule],
        to file: FileItem,
        index: Int,
        totalCount: Int
    ) -> Result<String, Error> {
        let url = file.url
        let ext = url.pathExtension
        var basename = ext.isEmpty ? file.name : String(file.name.dropLast(ext.count + 1))

        for rule in rules {
            switch rule {
            case .regexReplace(let pattern, let replacement, let caseInsensitive):
                do {
                    var options: NSRegularExpression.Options = []
                    if caseInsensitive {
                        options.insert(.caseInsensitive)
                    }
                    let regex = try NSRegularExpression(pattern: pattern, options: options)
                    let range = NSRange(basename.startIndex..., in: basename)
                    basename = regex.stringByReplacingMatches(
                        in: basename,
                        options: [],
                        range: range,
                        withTemplate: replacement
                    )
                } catch {
                    return .failure(error)
                }

            case .findReplace(let find, let replace):
                basename = basename.replacingOccurrences(of: find, with: replace)

            case .sequentialNumber(let position, let start, let step, let padding):
                let number = start + index * step
                let formatted = String(format: "%0\(padding)d", number)
                basename = applyInsert(formatted, to: basename, at: position)

            case .dateInsertion(let position, let format, let source):
                let date: Date
                switch source {
                case .fileModified:
                    date = file.dateModified ?? Date()
                case .currentDate:
                    date = Date()
                }
                let formatter = DateFormatter()
                formatter.dateFormat = format
                let dateString = formatter.string(from: date)
                basename = applyInsert(dateString, to: basename, at: position)

            case .caseConversion(let type):
                basename = convertCase(basename, to: type)
            }
        }

        if ext.isEmpty {
            return .success(basename)
        } else {
            return .success("\(basename).\(ext)")
        }
    }

    private func applyInsert(
        _ text: String,
        to basename: String,
        at position: BatchRenameRule.InsertPosition
    ) -> String {
        switch position {
        case .prefix:
            return text + basename
        case .suffix:
            return basename + text
        case .replace:
            return text
        }
    }

    private func convertCase(
        _ string: String,
        to type: BatchRenameRule.CaseConversionType
    ) -> String {
        switch type {
        case .upper:
            return string.uppercased()
        case .lower:
            return string.lowercased()
        case .title:
            return string.capitalized
        case .camelCase:
            return toCamelCase(string)
        case .snakeCase:
            return toSnakeCase(string)
        }
    }

    private func toCamelCase(_ string: String) -> String {
        let words = splitIntoWords(string)
        guard let first = words.first else {
            return string
        }
        let rest = words.dropFirst().map(\.capitalized)
        return first.lowercased() + rest.joined()
    }

    private func toSnakeCase(_ string: String) -> String {
        let words = splitIntoWords(string)
        return words.map { $0.lowercased() }.joined(separator: "_")
    }

    private func splitIntoWords(_ string: String) -> [String] {
        var words: [String] = []
        var currentWord = ""

        for char in string {
            if char == " " || char == "_" || char == "-" || char == "." {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
            } else if char.isUppercase && !currentWord.isEmpty && currentWord.last?.isUppercase == false {
                words.append(currentWord)
                currentWord = String(char)
            } else {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }

    private func markConflicts(
        _ entries: inout [BatchRenameEntry],
        batchURLs: Set<URL>,
        allDirectoryFiles: [FileItem]
    ) {
        var newNameCounts: [String: [Int]] = [:]
        for (index, entry) in entries.enumerated() {
            if entry.errorMessage != nil {
                continue
            }
            newNameCounts[entry.newName.lowercased(), default: []].append(index)
        }

        for (_, indices) in newNameCounts where indices.count > 1 {
            for index in indices {
                let entry = entries[index]
                entries[index] = BatchRenameEntry(
                    originalURL: entry.originalURL,
                    originalName: entry.originalName,
                    newName: entry.newName,
                    hasConflict: true,
                    errorMessage: "Duplicate name in batch"
                )
            }
        }

        let newNamesInBatch = Set(entries.map { $0.newName.lowercased() })
        let existingNames = Set(
            allDirectoryFiles
                .filter { !batchURLs.contains($0.url) }
                .map { $0.name.lowercased() }
        )

        let collisions = newNamesInBatch.intersection(existingNames)
        guard !collisions.isEmpty else {
            return
        }

        for index in entries.indices {
            let entry = entries[index]
            if entry.hasConflict || entry.errorMessage != nil {
                continue
            }
            if collisions.contains(entry.newName.lowercased()) && entry.newName != entry.originalName {
                entries[index] = BatchRenameEntry(
                    originalURL: entry.originalURL,
                    originalName: entry.originalName,
                    newName: entry.newName,
                    hasConflict: true,
                    errorMessage: "Name conflicts with existing file"
                )
            }
        }
    }
}
