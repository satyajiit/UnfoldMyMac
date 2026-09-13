import SwiftUI
import UnfoldMyMacCore

struct UnfoldMyMacView: View {
    @Bindable var shell: AppShellModel
    let effects: EffectsModel
    let wallpaper: WallpaperModel
    @Palette private var palette

    var body: some View {
        NavigationSplitView {
            List(selection: $shell.route) {
                Section("Discover") {
                    ForEach(AppRoute.features) { route in
                        HStack {
                            Label(route.title, systemImage: route.symbol)
                            if route == .scenes {
                                Spacer(minLength: 2)
                                ContentBadge(title: "New", highlighted: true, selected: shell.route == route)
                            }
                        }.tag(route)
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
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.horizontal, 12).padding(.bottom, 4)
                    SidebarSupport()
                    Button { shell.show(.settings) } label: {
                        Label("Settings", icon: .appSettings)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .contentShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.ink)
                    .background(shell.route == .settings ? palette.ink.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
                    .accessibilityAddTraits(shell.route == .settings ? [.isSelected] : [])
                    .accessibilityIdentifier("route.settings")
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch shell.route ?? .effects {
                case .effects: EffectsFeatureView(model: effects, shell: shell)
                case .wallpaper: WallpaperFeatureView(model: wallpaper, collection: .wallpapers)
                case .scenes: WallpaperFeatureView(model: wallpaper, collection: .scenes)
                case .settings: SettingsPage(model: effects)
                }
            }
        }
        .font(UnfoldMyMacType.body)
        .tint(palette.controlAccent)
        .frame(minWidth: 900, minHeight: 620)
        .onExitCommand { effects.stopPreview() }
    }
}
