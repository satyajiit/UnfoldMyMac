import SwiftUI
import UnfoldMyMacCore

struct WallpaperTemplateSetupSheet: View {
    @Bindable var setup: WallpaperSetupController
    let request: WallpaperSetupRequest
    @State private var formHeight: CGFloat = 420
    private var maximumFormHeight: CGFloat { max(240, min(540, (NSScreen.main?.visibleFrame.height ?? 900)-240)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeading(title: request.template.title, subtitle: "Connections and settings for this wallpaper.")
            ScrollView {
              VStack(alignment: .leading, spacing: 22) {
               ForEach(request.template.setup ?? []) { requirement in
                if let connector = setup.registry.connector(requirement.id) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(connector.title).font(UnfoldMyMacType.title3)
                            Spacer()
                            Text(requirement.required ? "Required" : "Optional").font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
                        }
                        WallpaperConnectorFormView(connector: connector, connection: connection(requirement.id))
                    }
                    Divider()
                }
               }
              }.onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { formHeight = $0 }
            }
            .frame(height: min(formHeight, maximumFormHeight))
            .scrollBounceBehavior(.basedOnSize)
            HStack {
                Button("Cancel") { setup.cancel() }.keyboardShortcut(.cancelAction).modifier(UnfoldMyMacButtonStyle())
                Spacer()
                Button(request.applyAfterSetup ? "Use wallpaper" : "Save changes") { setup.finish() }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true))
                    .disabled(request.applyAfterSetup && !setup.draftReady)
                    .accessibilityIdentifier("wallpaper.setup.finish")
            }
        }.padding(28).frame(width: 552).fixedSize(horizontal: false, vertical: true)
            .font(UnfoldMyMacType.body)
    }
    private func connection(_ id: String) -> Binding<WallpaperConnectionSettings> {
        Binding(get: { setup.draft[id] ?? .init() }, set: { setup.draft[id] = $0 })
    }
}
