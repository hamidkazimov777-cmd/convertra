import Foundation
import CoreServices

/// Watches a single directory subtree for file-system changes via FSEvents and
/// invokes `onChange` when something appears/changes inside it. FSEvents
/// coalesces bursts (a folder of files dropped at once arrives as one-or-few
/// callbacks) using the latency below, so callers don't need their own
/// debounce for typical "downloaded a track" cases.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private var onChange: (() -> Void)?

    /// Starts watching `url`. Any previous watch is stopped first. Safe to call
    /// even if FSEvents can't create a stream — it simply won't fire.
    func start(url: URL, onChange: @escaping () -> Void) {
        stop()
        self.onChange = onChange

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.onChange?()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency (s) — coalesces rapid bursts of file changes
            flags
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        onChange = nil
    }

    deinit { stop() }
}
