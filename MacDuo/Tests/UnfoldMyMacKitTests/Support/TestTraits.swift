import Foundation
import Testing

extension Tag {
    /// Needs a real Metal device; skipped on continuous-integration runners.
    @Tag static var gpu: Self
    /// Creates real windows or panels; skipped on continuous-integration runners.
    @Tag static var window: Self
}

extension Trait where Self == ConditionTrait {
    /// GPU and window tests run on physical Macs only. GitHub Actions sets `CI=true`.
    static var requiresGPU: Self {
        .enabled(if: ProcessInfo.processInfo.environment["CI"] != "true", "GPU/window tests run on physical Macs")
    }
}

extension Trait where Self == ConditionTrait {
    /// Creates real panels or windows; needs a logged-in window server session.
    static var requiresWindowServer: Self {
        .enabled(if: ProcessInfo.processInfo.environment["CI"] != "true", "Window tests run on physical Macs")
    }
}
