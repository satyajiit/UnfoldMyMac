import SwiftUI
import UnfoldMyMacCore

/// Category navigation and scrollable settings share the draft without controlling the sheet's size.
struct WallpaperSetupContent: View {
    private enum Pane: String {
        case motion = "Motion", sound = "Sound", oneLiners = "One-liners", connections = "Connections"
    }
    @Bindable var setup: WallpaperSetupController
    let request: WallpaperSetupRequest
    @State private var pane: Pane = .motion

    private var hasGarden: Bool { request.template.setup?.contains { $0.id == "garden" } == true }
    private var panes: [Pane] {
        guard hasGarden else { return [.connections] }
        var result: [Pane] = [.motion]
        if request.template.setup?.contains(where: { $0.id == "microphone" }) == true { result.append(.sound) }
        result.append(.oneLiners)
        if request.template.setup?.contains(where: { $0.id != "garden" && $0.id != "microphone" }) == true {
            result.append(.connections)
        }
        return result
    }
    private var selection: Binding<Pane> {
        Binding(get: { panes.contains(pane) ? pane : panes[0] }, set: { pane = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            if panes.count > 1 {
                Picker("Category", selection: selection) {
                    ForEach(panes, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("wallpaper.setup.category")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            Divider()
            Form {
                switch selection.wrappedValue {
                case .motion:
                    WallpaperGardenSetup(connection: connection("garden"), inputs: setup.inputs)
                case .sound:
                    WallpaperSoundSetup(connection: connection("microphone"), inputs: setup.inputs)
                case .oneLiners:
                    WallpaperOneLinerSetup(connection: connection("garden"), soundEnabled: connection("microphone").wrappedValue.enabled)
                case .connections:
                    connections
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var connections: some View {
        ForEach(request.template.setup ?? []) { requirement in
            if let connector = setup.registry.connector(requirement.id), !hasGarden || (requirement.id != "garden" && requirement.id != "microphone") {
                if connector.form == .microphone {
                    WallpaperSoundSetup(connection: connection(requirement.id), inputs: setup.inputs)
                } else {
                    Section {
                        WallpaperConnectorFormView(connector: connector, connection: connection(requirement.id), inputs: setup.inputs)
                    } header: {
                        Text(connector.title)
                    } footer: {
                        Text(requirement.required ? "Required to use this wallpaper." : "Optional connection.")
                    }
                }
            }
        }
    }

    private func connection(_ id: String) -> Binding<WallpaperConnectionSettings> {
        Binding(get: { setup.draft[id] ?? .init() }, set: { setup.setDraft($0, for: id) })
    }
}
