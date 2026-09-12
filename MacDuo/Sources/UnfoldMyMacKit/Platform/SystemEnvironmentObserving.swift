import Foundation

/// Observable machine state. The composition root starts and stops the live implementation;
/// features only read `state` and react to its changes through observation.
@MainActor protocol SystemEnvironmentObserving: AnyObject {
    var state: SystemState { get }
    func start()
    func stop()
}
