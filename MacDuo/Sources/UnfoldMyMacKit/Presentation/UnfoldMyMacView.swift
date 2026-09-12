import SwiftUI
import UnfoldMyMacCore

struct UnfoldMyMacView: View {
    @Bindable var model: UnfoldMyMacModel
    let wallpaper: WallpaperModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        NavigationSplitView {
            List(selection: $model.route) {
                Section("Features") {
                    ForEach(AppRoute.features) { route in
                        Label(route.title, systemImage: route.symbol).tag(route)
                            .padding(.vertical, 5).accessibilityIdentifier("route.\(route.rawValue)")
                    }
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 10) {
                    BrandMark(size: 32)
                    Text(AppIdentity.name)
                        .font(UnfoldMyMacType.title3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(p.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { model.route = .settings } label: {
                    Label("Settings", icon: .appSettings)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .contentShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(p.ink)
                .background(model.route == .settings ? p.ink.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
                .accessibilityAddTraits(model.route == .settings ? [.isSelected] : [])
                .accessibilityIdentifier("route.settings")
                .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch model.route ?? .effects {
                case .effects: EffectsFeatureView(model: model)
                case .wallpaper: WallpaperFeatureView(model: wallpaper)
                case .settings: SettingsPage(model: model)
                }
            }
        }
        .font(UnfoldMyMacType.body)
        .tint(p.controlAccent)
        .frame(minWidth: 800, minHeight: 580)
        .onExitCommand { if model.isPreviewing { model.stopPreview() } }
    }
}
