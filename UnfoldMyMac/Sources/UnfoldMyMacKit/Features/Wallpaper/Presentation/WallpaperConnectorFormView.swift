import SwiftUI

/// The one switch from a connector's form kind to its view; plain forms share `WallpaperLocalConnectionSetup`.
struct WallpaperConnectorFormView: View {
    let connector: WallpaperConnectorDescriptor
    @Binding var connection: WallpaperConnectionSettings
    var inputs: WallpaperInputService? = nil
    var body: some View {
        switch connector.form {
        case .weather: WallpaperWeatherSetup(connection: $connection)
        case .restTimer: WallpaperRestSetup(connector: connector, connection: $connection)
        case .workshop: WallpaperWorkshopSetup(connection: $connection)
        case .desktopFolder: WallpaperDesktopFolderSetup(connection: $connection)
        case .garden: WallpaperGardenSetup(connection: $connection, inputs: inputs)
        case .microphone: WallpaperSoundSetup(connection: $connection, inputs: inputs)
        case .githubProfile: GitHubProfileSetup(connection: $connection)
        case .codexHooks: CodexActivitySetup(connection: $connection)
        case .claudeCode: ClaudeCodeSetup(connector: connector, connection: $connection)
        case .toggle, .file, .url: WallpaperLocalConnectionSetup(connector: connector, connection: $connection)
        }
    }
}
