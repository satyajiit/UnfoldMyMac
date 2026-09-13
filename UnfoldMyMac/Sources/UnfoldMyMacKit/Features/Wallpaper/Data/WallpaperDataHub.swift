import Foundation
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class WallpaperDataHub {
    private(set) var snapshot = WallpaperSnapshot()
    @ObservationIgnored private var tasks: [String: (identity: String, task: Task<Void, Never>)] = [:]
    @ObservationIgnored private var generation = UUID()

    /// Providers are matched by namespace and configuration fingerprint: a reconfigured provider restarts,
    /// an unchanged one keeps its task and last sample.
    func update(_ providers: [any WallpaperDataProvider]) {
        let requested = Dictionary(providers.map { ($0.id, Self.identity($0)) }, uniquingKeysWith: { first, _ in first })
        for (id, entry) in tasks where requested[id] != entry.identity {
            entry.task.cancel(); tasks[id] = nil
            snapshot.sources[id] = nil; snapshot.errors[id] = nil
        }
        let generation = self.generation
        for provider in providers where tasks[provider.id] == nil {
            tasks[provider.id] = (Self.identity(provider), Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        let sample = try await provider.sample(at: .now).validated(namespace: provider.id)
                        guard !Task.isCancelled, self?.generation == generation else { return }
                        self?.snapshot.sources[provider.id] = sample
                        self?.snapshot.errors[provider.id] = nil
                    } catch {
                        guard !Task.isCancelled, self?.generation == generation else { return }
                        self?.snapshot.errors[provider.id] = error.localizedDescription
                    }
                    do { try await Task.sleep(for: .seconds(max(0.5, provider.interval))) }
                    catch { return }
                }
            })
        }
    }
    static func identity(_ provider: any WallpaperDataProvider) -> String { provider.id + "#" + provider.fingerprint }
    func stop() {
        generation = UUID()
        tasks.values.forEach { $0.task.cancel() }; tasks.removeAll()
        snapshot = WallpaperSnapshot()
    }
}
