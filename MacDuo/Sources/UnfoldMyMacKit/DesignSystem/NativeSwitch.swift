import AppKit
import SwiftUI

/// An `NSSwitch` at its native small size. A plain hosting view keeps the toolbar from promoting the control to
/// its large size; the switch draws and lays out at the same dimensions everywhere.
struct NativeSwitch: NSViewRepresentable {
    @Binding var isOn: Bool
    var label: String
    /// The accessibility identifier UI tests and scripts address the control by.
    var identifier: String
    func makeCoordinator() -> Coordinator { Coordinator(isOn: $isOn) }
    func makeNSView(context: Context) -> SwitchHost {
        let host = SwitchHost()
        let control = host.control
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        return host
    }
    func updateNSView(_ host: SwitchHost, context: Context) {
        let control = host.control
        context.coordinator.isOn = $isOn
        control.state = isOn ? .on : .off
        control.setAccessibilityLabel(label)
        control.setAccessibilityIdentifier(identifier)
        control.toolTip = label
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SwitchHost, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
    @MainActor final class SwitchHost: NSView {
        let control = NSSwitch()
        override init(frame: NSRect) {
            super.init(frame: frame)
            control.controlSize = .small
            addSubview(control)
        }
        convenience init() { self.init(frame: .zero) }
        @available(*, unavailable) required init?(coder: NSCoder) { nil }
        override var intrinsicContentSize: NSSize { control.intrinsicContentSize }
        override func layout() {
            super.layout()
            let size = control.intrinsicContentSize
            control.frame = NSRect(x: (bounds.width - size.width) / 2,
                                   y: (bounds.height - size.height) / 2,
                                   width: size.width, height: size.height)
        }
    }
    @MainActor final class Coordinator: NSObject {
        var isOn: Binding<Bool>
        init(isOn: Binding<Bool>) { self.isOn = isOn }
        @objc func changed(_ sender: NSSwitch) { isOn.wrappedValue = sender.state == .on }
    }
}
