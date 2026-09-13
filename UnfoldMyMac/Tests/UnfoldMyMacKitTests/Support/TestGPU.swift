@testable import UnfoldMyMacKit

/// One GPU context for the whole test process, like the app: shader units compile once and pipeline states are shared.
@MainActor enum TestGPU {
    private static var cached: GPUContext?
    static func context() throws -> GPUContext {
        if let cached { return cached }
        let context = try GPUContext()
        cached = context
        return context
    }
}
