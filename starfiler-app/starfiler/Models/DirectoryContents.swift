import Foundation

struct DirectoryContents: Sendable {
    enum ContentFilter: Hashable, Sendable {
        case allFiles
        case mediaOnly
    }

    enum SortDescriptor: Hashable, Sendable {
        enum Column: Hashable, Sendable {
            case name
            case size
            case date
            case selection
        }

        case name(ascending: Bool)
        case size(ascending: Bool)
        case date(ascending: Bool)
        case selection(ascending: Bool)

        init(column: Column, ascending: Bool) {
            switch column {
            case .name:
                self = .name(ascending: ascending)
            case .size:
                self = .size(ascending: ascending)
            case .date:
                self = .date(ascending: ascending)
            case .selection:
                self = .selection(ascending: ascending)
            }
        }

        var column: Column {
            switch self {
            case .name:
                return .name
            case .size:
                return .size
            case .date:
                return .date
            case .selection:
                return .selection
            }
        }

        var ascending: Bool {
            switch self {
            case .name(let ascending), .size(let ascending), .date(let ascending), .selection(let ascending):
                return ascending
            }
        }
    }

    var allItems: [FileItem]
    var displayedItems: [FileItem]
    var sortDescriptor: SortDescriptor
    var filterText: String
    var showHiddenFiles: Bool
    var contentFilter: ContentFilter
    var treeExpansionState: TreeExpansionState = TreeExpansionState()
    private(set) var displayedTreeItems: [TreeDisplayItem] = []

    init(
        allItems: [FileItem] = [],
        displayedItems: [FileItem] = [],
        sortDescriptor: SortDescriptor = .name(ascending: true),
        filterText: String = "",
        showHiddenFiles: Bool = false,
        contentFilter: ContentFilter = .allFiles
    ) {
        self.allItems = allItems
        self.displayedItems = displayedItems
        self.sortDescriptor = sortDescriptor
        self.filterText = filterText
        self.showHiddenFiles = showHiddenFiles
        self.contentFilter = contentFilter
        recompute()
    }

    mutating func recompute() {
        var items = allItems

        if !showHiddenFiles {
            items = items.filter { !$0.isHidden }
        }

        switch contentFilter {
        case .allFiles:
            break
        case .mediaOnly:
            items = items.filter { !$0.isDirectory && $0.url.isMediaFile }
        }

        let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFilter.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(trimmedFilter) }
        }

        if sortDescriptor.column == .selection {
            if !sortDescriptor.ascending {
                items.reverse()
            }
            displayedItems = items
            rebuildTreeDisplayItems()
            return
        }

        items.sort(by: compare(_:_:))
        displayedItems = items
        rebuildTreeDisplayItems()
    }

    mutating func setSortDescriptor(_ sortDescriptor: SortDescriptor) {
        self.sortDescriptor = sortDescriptor
        recompute()
    }

    private func compare(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        if contentFilter == .allFiles {
            let lhsIsBrowsableDirectory = lhs.isDirectory && !lhs.isPackage
            let rhsIsBrowsableDirectory = rhs.isDirectory && !rhs.isPackage

            if lhsIsBrowsableDirectory != rhsIsBrowsableDirectory {
                return lhsIsBrowsableDirectory && !rhsIsBrowsableDirectory
            }
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
        case .date(let ascending):
            let lhsDate = lhs.dateModified ?? .distantPast
            let rhsDate = rhs.dateModified ?? .distantPast
            if lhsDate != rhsDate {
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
            return compareNames(lhs.name, rhs.name, ascending: true)
        case .selection:
            return false
        }
    }

    private mutating func rebuildTreeDisplayItems() {
        guard !treeExpansionState.expandedURLs.isEmpty else {
            displayedTreeItems = displayedItems.map { item in
                TreeDisplayItem(
                    fileItem: item,
                    depth: 0,
                    isExpanded: false,
                    isExpandable: item.isDirectory && !item.isPackage,
                    parentURL: nil
                )
            }
            return
        }

        var flatItems: [FileItem] = []
        var treeItems: [TreeDisplayItem] = []

        for item in displayedItems {
            flatItems.append(item)
            let isExpandable = item.isDirectory && !item.isPackage
            let isExpanded = isExpandable && treeExpansionState.isExpanded(item.url)
            treeItems.append(TreeDisplayItem(
                fileItem: item,
                depth: 0,
                isExpanded: isExpanded,
                isExpandable: isExpandable,
                parentURL: nil
            ))

            if isExpanded {
                insertExpandedChildren(
                    of: item.url,
                    depth: 1,
                    into: &flatItems,
                    treeItems: &treeItems
                )
            }
        }

        displayedItems = flatItems
        displayedTreeItems = treeItems
    }

    private func insertExpandedChildren(
        of parentURL: URL,
        depth: Int,
        into flatItems: inout [FileItem],
        treeItems: inout [TreeDisplayItem]
    ) {
        guard let children = treeExpansionState.childrenByParent[parentURL] else {
            return
        }

        let filtered = applyFiltersAndSort(to: children)

        for child in filtered {
            flatItems.append(child)
            let isExpandable = child.isDirectory && !child.isPackage
            let isExpanded = isExpandable && treeExpansionState.isExpanded(child.url)
            treeItems.append(TreeDisplayItem(
                fileItem: child,
                depth: depth,
                isExpanded: isExpanded,
                isExpandable: isExpandable,
                parentURL: parentURL
            ))

            if isExpanded {
                insertExpandedChildren(
                    of: child.url,
                    depth: depth + 1,
                    into: &flatItems,
                    treeItems: &treeItems
                )
            }
        }
    }

    private func applyFiltersAndSort(to items: [FileItem]) -> [FileItem] {
        var result = items

        if !showHiddenFiles {
            result = result.filter { !$0.isHidden }
        }

        switch contentFilter {
        case .allFiles:
            break
        case .mediaOnly:
            result = result.filter { !$0.isDirectory && $0.url.isMediaFile }
        }

        let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFilter.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(trimmedFilter) }
        }

        if sortDescriptor.column == .selection {
            if !sortDescriptor.ascending {
                result.reverse()
            }
            return result
        }

        result.sort(by: compare(_:_:))
        return result
    }

    private func compareNames(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
        let result = lhs.localizedStandardCompare(rhs)
        if result == .orderedSame {
            return false
        }
        return ascending ? result == .orderedAscending : result == .orderedDescending
    }
}
