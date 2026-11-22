import Foundation

/// Preparation never answered: a Speech call that never returns, rather than a download that
/// stopped. Set up or Try again starts it over, so the screen never stays on "Checking the
/// speech model" forever.
nonisolated struct SpeechModelUnresponsive: HexDescribedError {
    var errorDescription: String? {
        String(localized: "The speech model didn't respond. Try again.")
    }
}

/// Runs one preparation step under `StallWatch`'s deadline, which doesn't count time iOS has
/// Hex suspended, and reports it as `SpeechModelUnresponsive` instead of a stopped download.
/// `progress` is 0 while the step has said nothing and nil once it has, so only the silent part
/// is bounded: a model that compiles after its first report may take as long as it needs.
nonisolated enum SpeechModelDeadline {
    static func run<T: Sendable>(
        _ limit: Duration,
        progress: @escaping @Sendable () -> Double?,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        do {
            return try await StallWatch.run(limit: limit, progress: progress, operation: operation)
        } catch is StallWatch.Stalled {
            throw SpeechModelUnresponsive()
        }
    }
}
