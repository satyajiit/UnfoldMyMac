import SwiftUI

struct WallpaperWeatherSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    @State private var query = ""
    @State private var results: [WallpaperWeatherLocation] = []
    @State private var loading = false
    @State private var error: String?
    @State private var request: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a city for this wallpaper. Weather, wind and sun times follow that city. Only your search and the selected city's coordinates are sent to Open-Meteo.")
                .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("City", text: $query, prompt: Text("City, region or country")).textFieldStyle(.roundedBorder).labelsHidden()
                    .accessibilityLabel("City, region or country")
                    .accessibilityIdentifier("wallpaper.weather.city").onSubmit { search() }
                Button("Find city") { search() }.disabled(loading || query.trimmingCharacters(in: .whitespaces).count < 2)
                    .modifier(UnfoldMyMacButtonStyle()).fixedSize()
            }
            .onChange(of: query) { _, _ in request?.cancel(); loading = false; results = []; error = nil }
            if loading { ProgressView("Finding cities…") }
            if let error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            ForEach(results) { location in
                Button {
                    connection.weatherLocation = location; connection.enabled = true; results = []
                } label: {
                    Label(location.label, systemImage: "mappin.circle").frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.bordered)
            }
            if connection.enabled, let location = connection.weatherLocation {
                Label(location.label, systemImage: "checkmark.circle.fill").font(UnfoldMyMacType.headline)
                    .accessibilityIdentifier("wallpaper.weather.selected")
                Button("Disconnect city") { connection.weatherLocation = nil; connection.enabled = false }.buttonStyle(.plain)
            }
            Text("Forecast conditions refresh every 10 minutes. Offline readings expire after two hours. Temperatures use °C; wind uses km/h.")
                .font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            Link("Weather by Open-Meteo · city data by GeoNames", destination: URL(string: "https://open-meteo.com/")!)
                .font(UnfoldMyMacType.caption)
        }.onDisappear { request?.cancel() }
    }
    private func search() {
        request?.cancel(); loading = true; error = nil; results = []
        let input = query
        request = Task {
            do {
                let found = try await WallpaperWeatherLocation.search(input)
                guard !Task.isCancelled else { return }
                results = found; loading = false
                if found.isEmpty { error = "No city found. Try adding a country or region." }
            } catch {
                guard !Task.isCancelled else { return }
                self.error = "City search is unavailable. Try again shortly."; loading = false
            }
        }
    }
}
