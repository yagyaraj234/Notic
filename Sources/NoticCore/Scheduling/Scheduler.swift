import Foundation

/// A handle to scheduled work that can be cancelled before it fires.
public protocol ScheduledWork: AnyObject {
    func cancel()
}

/// The workspace's only source of time. Production uses the system clock and
/// timers; tests use `TestScheduler` to advance time deterministically.
public protocol NoticScheduler: AnyObject {
    var now: Date { get }
    func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledWork
}

/// The delays that shape Notic's behaviour, in seconds.
public nonisolated enum NoticTiming {
    /// Sustained hover before the dormant pill fans out. Long enough that a
    /// pointer crossing the edge on its way somewhere else leaves the deck
    /// asleep; the Open delay preference tunes it per taste.
    public static let hoverExpandDelay: TimeInterval = 0.350
    /// Grace period after the pointer leaves before the deck collapses.
    public static let collapseGrace: TimeInterval = 0.350
    /// Trailing debounce after typing stops before an autosave.
    public static let autosaveDebounce: TimeInterval = 0.250
    /// Window in which a deletion can be undone.
    public static let deletionGrace: TimeInterval = 10
    /// Wait before retrying a failed save.
    public static let saveRetryInterval: TimeInterval = 2
}

/// Deterministic scheduler for tests. Work runs only when `advance(by:)` moves
/// the clock past its due time.
public final class TestScheduler: NoticScheduler {
    private final class Entry: ScheduledWork {
        let id: UUID
        let dueAt: Date
        let action: @MainActor () -> Void
        weak var owner: TestScheduler?

        init(dueAt: Date, action: @escaping @MainActor () -> Void, owner: TestScheduler) {
            self.id = UUID()
            self.dueAt = dueAt
            self.action = action
            self.owner = owner
        }

        func cancel() {
            owner?.remove(self)
        }
    }

    public private(set) var now: Date
    private var entries: [Entry] = []

    public init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.now = now
    }

    public func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledWork {
        let entry = Entry(dueAt: now.addingTimeInterval(interval), action: action, owner: self)
        entries.append(entry)
        return entry
    }

    /// Moves the clock forward, running every piece of work that comes due in
    /// the order it was scheduled to fire.
    public func advance(by interval: TimeInterval) {
        let target = now.addingTimeInterval(interval)
        while let next = entries.filter({ $0.dueAt <= target }).min(by: { $0.dueAt < $1.dueAt }) {
            now = max(now, next.dueAt)
            remove(next)
            next.action()
        }
        now = target
    }

    private func remove(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
    }
}

/// Wall-clock scheduler backed by main-queue timers.
public final class SystemScheduler: NoticScheduler {
    private final class TimerWork: ScheduledWork {
        var timer: Timer?
        func cancel() {
            timer?.invalidate()
            timer = nil
        }
    }

    public init() {}

    public var now: Date { Date() }

    public func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledWork {
        let work = TimerWork()
        let timer = Timer(timeInterval: interval, repeats: false) { _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        work.timer = timer
        return work
    }
}
