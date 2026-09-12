import Foundation

struct NOAAWeatherState: Sendable {
    var forecast: NOAAForecast?
    var kp: NOAAKp?
    var forecastFailed = false
    var kpFailed = false
}

/// One request per feed per five minutes, shared by preview and desktop providers.
actor NOAAWeatherStore {
    static let shared = NOAAWeatherStore()
    private let client: NOAAWeatherClient
    private var state = NOAAWeatherState()
    private var nextFetch = Date.distantPast
    private var pending: Task<NOAAWeatherState, Never>?
    init(client: NOAAWeatherClient = .init()) { self.client = client }
    func read(at date: Date) async throws -> NOAAWeatherState {
        try Task.checkCancellation()
        if let pending { let value = await pending.value; try Task.checkCancellation(); return value }
        guard date >= nextFetch else { return state }
        let previous = state, client = client
        let task = Task {
            async let forecast = try? client.forecast()
            async let kp = try? client.kp()
            let (f, k) = await (forecast, kp)
            return NOAAWeatherState(forecast: f ?? previous.forecast, kp: k ?? previous.kp,
                                    forecastFailed: f == nil, kpFailed: k == nil)
        }
        pending = task
        let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        pending = nil
        try Task.checkCancellation()
        state = result; nextFetch = date.addingTimeInterval(300)
        return state
    }
}
