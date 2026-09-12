/// Writes an observable property only when its value changes, so a steady state produces no invalidations (P7).
@MainActor protocol ChangeGuardedPublishing: AnyObject {}

extension ChangeGuardedPublishing {
    func publish<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
