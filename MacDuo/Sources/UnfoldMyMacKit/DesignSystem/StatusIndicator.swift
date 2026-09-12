import SwiftUI
import UnfoldMyMacCore

struct StatusIndicator: View {
    let text: String
    let enabled: Bool
    var body: some View {
        Label(text, icon: enabled ? .selected : .idle)
            .font(UnfoldMyMacType.callout).lineLimit(2).accessibilityElement(children: .combine)
    }
}
