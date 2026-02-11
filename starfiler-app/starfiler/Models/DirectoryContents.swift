import Foundation

struct DirectoryContents: Sendable {
    enum SortDescriptor: Hashable, Sendable {
        case name(ascending: Bool)
        case size(ascending: Bool)
        case dateModified(ascending: Bool)
    }

    var allItems: [FileItem]
    var displayedItems: [FileItem]
    var sortDescriptor: SortDescriptor
    var filterText: String
    var showHiddenFiles: Bool

    init(
        allItems: [FileItem] = [],
        displayedItems: [FileItem] = [],
        sortDescriptor: SortDescriptor = .name(ascending: true),
        filterText: String = "",
        showHiddenFiles: Bool = false
    ) {
        self.allItems = allItems
        self.displayedItems = displayedItems
        self.sortDescriptor = sortDescriptor
        self.filterText = filterText
        self.showHiddenFiles = showHiddenFiles
        recompute()
    }

    mutating func recompute() {
        var items = allItems

        if !showHiddenFiles {
            items = items.filter { !$0.isHidden }
        }

        let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFilter.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(trimmedFilter) }
        }

        items.sort(by: compare(_:_:))
        displayedItems = items
    }

    private func compare(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        let lhsIsBrowsableDirectory = lhs.isDirectory && !lhs.isPackage
        let rhsIsBrowsableDirectory = rhs.isDirectory && !rhs.isPackage

        if lhsIsBrowsableDirectory != rhsIsBrowsableDirectory {
            return lhsIsBrowsableDirectory && !rhsIsBrowsableDirectory
        }

        switch sortDescriptor {
        case .name(let ascending):
            return compareNames(lhs.name, rhs.name, ascending: ascending)
        case .size(let ascending):
            let lhsSize = lhs.size ?? -1
            let rhsSize = rhs.size ?? -1
            if lhsSize != rhsSize {
                return ascending ? lhsSize < rhsSize : lhsSize > rhsSize
            }
            return compareNames(lhs.name, rhs.name, ascending: true)
        case .dateModified(let ascending):
            let lhsDate = lhs.dateModified ?? .distantPast
            let rhsDate = rhs.dateModified ?? .distantPast
            if lhsDate != rhsDate {
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
            return compareNames(lhs.name, rhs.name, ascending: true)
        }
    }

    private func compareNames(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
        let result = lhs.localizedStandardCompare(rhs)
        if result == .orderedSame {
            return false
        }
        return ascending ? result == .orderedAscending : result == .orderedDescending
    }
}
