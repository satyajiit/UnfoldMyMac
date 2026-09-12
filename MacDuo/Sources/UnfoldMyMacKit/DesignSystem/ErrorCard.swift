import SwiftUI
import UnfoldMyMacCore

struct ErrorCard: View {
    let message: String
    var needsPermission: Bool
    var openScreenRecordingSettings: (() -> Void)? = nil
    var body: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("A little setup is needed", icon: .warning).font(UnfoldMyMacType.headline)
                Text(message).font(UnfoldMyMacType.callout).fixedSize(horizontal: false, vertical: true)
                if needsPermission, let openScreenRecordingSettings {
                    Button("Open Screen Recording Settings", action: openScreenRecordingSettings).modifier(UnfoldMyMacButtonStyle())
                }
            }
        }.accessibilityElement(children: .contain)
    }
}
