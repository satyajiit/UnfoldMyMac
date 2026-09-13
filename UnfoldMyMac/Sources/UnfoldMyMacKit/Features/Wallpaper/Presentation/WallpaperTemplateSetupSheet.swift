import SwiftUI
import UnfoldMyMacCore

struct WallpaperTemplateSetupSheet: View {
    @Bindable var setup: WallpaperSetupController
    let request: WallpaperSetupRequest

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.template.title).font(UnfoldMyMacType.title2)
                Text(request.template.contentCollection == .scenes ? "Scene settings" : "Wallpaper settings").font(UnfoldMyMacType.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            WallpaperSetupContent(setup: setup, request: request)
            Divider()
            HStack(spacing: 12) {
                Text(request.template.id == "the-workshop" ? "Folder connects when saved." : request.template.setup?.contains(where: { $0.id == "garden" }) == true
                     ? "Changes preview live." : "Settings apply when saved.")
                    .font(UnfoldMyMacType.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { setup.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
                Button(request.applyAfterSetup ? request.template.contentCollection.actionTitle : "Save Changes") { setup.finish() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(request.applyAfterSetup && !setup.draftReady)
                    .accessibilityIdentifier("wallpaper.setup.finish")
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        // Content and permission updates never change the sheet's size.
        .frame(width: 640, height: min(580, max(420, (NSScreen.main?.visibleFrame.height ?? 900) - 120)))
        .background(Color(nsColor: .windowBackgroundColor))
        .font(UnfoldMyMacType.body)
    }
}
