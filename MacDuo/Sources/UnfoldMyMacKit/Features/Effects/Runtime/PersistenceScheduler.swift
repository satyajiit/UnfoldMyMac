import Foundation

/// Coalesces writes from continuous controls: a slider that persists on every tick writes once, `delay` after
/// the last change (P15). A zero delay runs the work at once, which keeps tests synchronous.
@MainActor final class PersistenceScheduler {
    private let delay: Duration
    private var pending: Task<Void, Never>?
    private var work: (@MainActor () -> Void)?

    init(delay: Duration) { self.delay = delay }

    func schedule(_ work: @escaping @MainActor () -> Void) {
        guard delay > .zero else { work(); return }
        self.work = work
        guard pending == nil else { return }
        let delay = self.delay
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
    /// Runs the pending write now, if any.
    func flush() {
        pending?.cancel(); pending = nil
        let work = self.work
        self.work = nil
        work?()
    }
    isolated deinit { pending?.cancel() }
}
