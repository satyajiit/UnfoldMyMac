import Observation

/// Observes a `SystemEnvironmentObserving` and delivers the events a feature reacts to, diffing successive
/// states so the feature keeps no history itself. The current state is delivered on start.
@MainActor final class SystemStateSubscriber {
    enum Event: Equatable, Sendable { case sleep, wake, displaysChanged, accessibility(reduceTransparency: Bool, reduceMotion: Bool) }
    private let environment: any SystemEnvironmentObserving
    private var last: SystemState?
    private var observation: Task<Void, Never>?

    init(environment: any SystemEnvironmentObserving) { self.environment = environment }

    func start(_ handle: @escaping @MainActor (Event) -> Void) {
        stop()
        deliver(environment.state, to: handle)
        let environment = self.environment
        observation = Task { [weak self] in
            for await state in Observations({ environment.state }) { self?.deliver(state, to: handle) }
        }
    }
    func stop() { observation?.cancel(); observation = nil }
    isolated deinit { stop() }

    /// Sleep and wake follow display availability, never the login session; the first state never wakes.
    nonisolated static func events(from previous: SystemState?, to state: SystemState) -> [Event] {
        var events: [Event] = []
        if state.displaysUnavailable != previous?.displaysUnavailable {
            if state.displaysUnavailable { events.append(.sleep) } else if previous != nil { events.append(.wake) }
        }
        if let previous, state.displayGeneration != previous.displayGeneration { events.append(.displaysChanged) }
        events.append(.accessibility(reduceTransparency: state.reduceTransparency, reduceMotion: state.reduceMotion))
        return events
    }
    private func deliver(_ state: SystemState, to handle: @MainActor (Event) -> Void) {
        let events = Self.events(from: last, to: state)
        last = state
        for event in events { handle(event) }
    }
}
