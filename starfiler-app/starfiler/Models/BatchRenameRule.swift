import Foundation

enum BatchRenameRule: Codable, Hashable, Sendable {
    case regexReplace(pattern: String, replacement: String, caseInsensitive: Bool)
    case findReplace(find: String, replace: String)
    case sequentialNumber(position: InsertPosition, start: Int, step: Int, padding: Int)
    case dateInsertion(position: InsertPosition, format: String, source: DateSource)
    case caseConversion(CaseConversionType)

    enum InsertPosition: String, Codable, Hashable, Sendable {
        case prefix
        case suffix
        case replace
    }

    enum DateSource: String, Codable, Hashable, Sendable {
        case fileModified
        case currentDate
    }

    enum CaseConversionType: String, Codable, Hashable, Sendable {
        case upper
        case lower
        case title
        case camelCase
        case snakeCase
    }

    var displayDescription: String {
        switch self {
        case .regexReplace(let pattern, let replacement, _):
            return "Regex: \"\(pattern)\" → \"\(replacement)\""
        case .findReplace(let find, let replace):
            return "Replace: \"\(find)\" → \"\(replace)\""
        case .sequentialNumber(let position, let start, let step, let padding):
            let sample = String(format: "%0\(padding)d", start)
            return "Number: \(position.rawValue), \(sample), step=\(step)"
        case .dateInsertion(let position, let format, let source):
            return "Date: \(position.rawValue), \(format), \(source.rawValue)"
        case .caseConversion(let type):
            return "Case: \(type.rawValue)"
        }
    }
}
