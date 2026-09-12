import Foundation
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class WallpaperDataHub {
    private(set) var snapshot = WallpaperSnapshot()
    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var generation = UUID()

    func update(_ providers: [any WallpaperDataProvider]) {
        let requested = Set(providers.map(\.id))
        for id in tasks.keys where !requested.contains(id) {
            tasks.removeValue(forKey: id)?.cancel()
            snapshot.sources[id] = nil; snapshot.errors[id] = nil
        }
        let generation = self.generation
        for provider in providers where tasks[provider.id] == nil {
            tasks[provider.id] = Task { [weak self] in
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
            }
        }
    }
    func stop() {
        generation = UUID()
        tasks.values.forEach { $0.cancel() }; tasks.removeAll()
        snapshot = WallpaperSnapshot()
    }
}
