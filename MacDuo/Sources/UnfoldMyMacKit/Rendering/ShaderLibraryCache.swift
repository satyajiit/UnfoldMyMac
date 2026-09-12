import CryptoKit
import Foundation
import Metal

/// Compiles each shader unit once per process. A unit is addressed by the digest of the exact source it
/// compiles, so a precompiled `Compiled/<digest>.metallib` in the bundle is used when present and the
/// runtime source compiler otherwise; both paths yield the same functions.
@MainActor final class ShaderLibraryCache {
    enum Policy { case preferPrecompiled, sourceOnly }
    let policy: Policy
    private let device: MTLDevice
    private var libraries: [String: MTLLibrary] = [:]
    private var sources: [String: String] = [:]
    private var keys: [ShaderModule: String] = [:]
    private(set) var compiledFromSource = 0
    private(set) var loadedPrecompiled = 0
    /// Why a precompiled unit was not used, per unit key; diagnostics print these.
    private(set) var precompiledProblems: [String: String] = [:]

    init(device: MTLDevice, policy: Policy = .preferPrecompiled) { self.device = device; self.policy = policy }

    func library(for module: ShaderModule) throws -> MTLLibrary {
        let key = try unitKey(for: module)
        if let cached = libraries[key] { return cached }
        let library: MTLLibrary
        if policy == .preferPrecompiled, let precompiled = loadPrecompiled(key: key, for: module) {
            library = precompiled; loadedPrecompiled += 1
        } else {
            let options = MTLCompileOptions()
            options.mathMode = module.mathMode.metal
            library = try device.makeLibrary(source: try source(for: module), options: options)
            compiledFromSource += 1
        }
        libraries[key] = library
        return library
    }
    /// The text the unit compiles: its resources joined in order. `script/compile_shaders.sh` builds the same text.
    func source(for module: ShaderModule) throws -> String {
        try module.resources.map { try source(named: $0, family: module.family) }.joined(separator: "\n")
    }
    /// SHA-256 of the compiled text plus the math mode; the precompiled file name.
    func unitKey(for module: ShaderModule) throws -> String {
        if let key = keys[module] { return key }
        let key = Self.digest(source: try source(for: module), mathMode: module.mathMode)
        keys[module] = key
        return key
    }
    static func digest(source: String, mathMode: ShaderMathMode) -> String {
        let text = source + "\n// mathMode=" + mathMode.rawValue
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func loadPrecompiled(key: String, for module: ShaderModule) -> MTLLibrary? {
        guard let url = BundleResources.compiledShader(key) else {
            precompiledProblems[module.id] = "no Compiled/\(key).metallib in the bundle"; return nil
        }
        do { return try device.makeLibrary(URL: url) }
        catch { precompiledProblems[module.id] = error.localizedDescription; return nil }
    }
    private func source(named name: String, family: BundleResources.ShaderFamily) throws -> String {
        let path = "\(family.rawValue)/\(name)"
        if let text = sources[path] { return text }
        let text = try BundleResources.shaderSource(name, family: family)
        sources[path] = text
        return text
    }
}
