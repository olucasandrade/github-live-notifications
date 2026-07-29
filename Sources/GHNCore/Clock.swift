import Foundation

/// Injectable time source for scheduling (tests use `FakeClock`).
public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(until: Date) async throws
}

public struct SystemClock: Clock {
    public init() {}

    public var now: Date { Date() }

    public func sleep(until date: Date) async throws {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}

/// Deterministic clock for unit tests — `sleep` records targets and jumps `now`.
public final class FakeClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    public private(set) var sleepTargets: [Date] = []

    public init(now: Date = Date(timeIntervalSince1970: 0)) {
        _now = now
    }

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _now = _now.addingTimeInterval(interval)
    }

    public func sleep(until date: Date) async throws {
        lock.lock()
        sleepTargets.append(date)
        lock.unlock()
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try Task.checkCancellation()
    }
}
