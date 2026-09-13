import Foundation

struct NOAAWeatherState: Sendable {
    var forecast: NOAAForecast?
    var kp: NOAAKp?
    var forecastFailed = false
    var kpFailed = false
}
