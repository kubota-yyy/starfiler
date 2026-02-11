import Dispatch
import Foundation

protocol DirectoryMonitoring: AnyObject {
    func startMonitoring(url: URL, handler: @escaping () -> Void)
    func stopMonitoring()
    func suspend()
    func resume()
}

final class DirectoryMonitor: DirectoryMonitoring {
    private let queue: DispatchQueue
    private let callbackQueue: DispatchQueue
    private let debounceInterval: TimeInterval

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var suspensionCount = 0
    private var pendingDebounceWorkItem: DispatchWorkItem?
    private var handler: (() -> Void)?

    init(
        queue: DispatchQueue = DispatchQueue(label: "com.nilone.starfiler.directory-monitor"),
        callbackQueue: DispatchQueue = .main,
        debounceInterval: TimeInterval = 0.2
    ) {
        self.queue = queue
        self.callbackQueue = callbackQueue
        self.debounceInterval = debounceInterval
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring(url: URL, handler: @escaping () -> Void) {
        stopMonitoring()

        let normalizedURL = url.standardizedFileURL
        let descriptor = open(normalizedURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            return
        }

        fileDescriptor = descriptor
        self.handler = handler

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib, .link, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedHandler()
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        suspensionCount = 0
        source.resume()
    }

    func stopMonitoring() {
        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil
        handler = nil

        guard let source else {
            suspensionCount = 0
            if fileDescriptor >= 0 {
                close(fileDescriptor)
                fileDescriptor = -1
            }
            return
        }

        while suspensionCount > 0 {
            source.resume()
            suspensionCount -= 1
        }

        source.cancel()
        self.source = nil
        suspensionCount = 0
    }

    func suspend() {
        guard let source else {
            return
        }

        suspensionCount += 1
        guard suspensionCount == 1 else {
            return
        }

        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil
        source.suspend()
    }

    func resume() {
        guard let source, suspensionCount > 0 else {
            return
        }

        suspensionCount -= 1
        guard suspensionCount == 0 else {
            return
        }

        source.resume()
    }

    private func scheduleDebouncedHandler() {
        pendingDebounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let handler = self.handler else {
                return
            }

            self.callbackQueue.async(execute: handler)
        }

        pendingDebounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
