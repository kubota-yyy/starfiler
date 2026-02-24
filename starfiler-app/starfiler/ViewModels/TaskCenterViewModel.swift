import Foundation

@MainActor
final class TaskCenterViewModel {
    private static let maxHistoryEntries = 50

    private(set) var entries: [TaskCenterEntry] = []

    var onCopyErrorDetailRequested: ((String) -> Void)?
    var onRetryRequested: ((FileOperation) -> Void)?
    var onCancelRequested: ((TaskCenterEntryID) -> Void)?

    var onEntriesChanged: (() -> Void)?
    var onActiveCountChanged: ((Int) -> Void)?
    var onHasFailedEntriesChanged: ((Bool) -> Void)?

    var activeEntries: [TaskCenterEntry] {
        entries.filter { !$0.isTerminal }
    }

    var historyEntries: [TaskCenterEntry] {
        entries.filter { $0.isTerminal }
    }

    var activeCount: Int {
        entries.count(where: { !$0.isTerminal })
    }

    var hasFailedEntries: Bool {
        entries.contains(where: {
            if case .failed = $0.status { return true }
            return false
        })
    }

    // MARK: - Entry Lifecycle

    func addEntry(id: TaskCenterEntryID, operation: FileOperation) {
        let entry = TaskCenterEntry(
            id: id,
            operation: operation,
            startedAt: Date(),
            status: .running(completed: 0, total: operation.totalUnitCount, currentFile: URL(fileURLWithPath: "/"))
        )
        entries.insert(entry, at: 0)
        notifyChanges()
    }

    func updateProgress(id: TaskCenterEntryID, completed: Int, total: Int, currentFile: URL) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index].status = .running(completed: completed, total: total, currentFile: currentFile)
        onEntriesChanged?()
    }

    func markCompleted(id: TaskCenterEntryID, record: FileOperationRecord) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index].status = .completed(record: record)
        trimHistory()
        notifyChanges()
    }

    func markFailed(id: TaskCenterEntryID, error: FileOperationError, detail: TaskCenterErrorDetail) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index].status = .failed(error: error.message, detail: detail)
        trimHistory()
        notifyChanges()
    }

    func markCancelled(id: TaskCenterEntryID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index].status = .cancelled
        trimHistory()
        notifyChanges()
    }

    func clearHistory() {
        entries.removeAll { $0.isTerminal }
        notifyChanges()
    }

    func removeEntry(id: TaskCenterEntryID) {
        entries.removeAll { $0.id == id }
        notifyChanges()
    }

    // MARK: - Actions

    func copyErrorDetail(for entryID: TaskCenterEntryID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              case .failed(_, let detail) = entry.status else {
            return
        }
        onCopyErrorDetailRequested?(detail.copyableText)
    }

    func retryFailedEntry(_ entryID: TaskCenterEntryID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              case .failed = entry.status else {
            return
        }
        removeEntry(id: entryID)
        onRetryRequested?(entry.operation)
    }

    func cancelEntry(_ entryID: TaskCenterEntryID) {
        onCancelRequested?(entryID)
    }

    // MARK: - Private

    private func trimHistory() {
        let terminal = entries.filter { $0.isTerminal }
        if terminal.count > Self.maxHistoryEntries {
            let idsToRemove = Set(terminal.suffix(terminal.count - Self.maxHistoryEntries).map(\.id))
            entries.removeAll { idsToRemove.contains($0.id) }
        }
    }

    private func notifyChanges() {
        onEntriesChanged?()
        onActiveCountChanged?(activeCount)
        onHasFailedEntriesChanged?(hasFailedEntries)
    }
}
