import SwiftUI
import UnfoldMyMacCore

struct ParameterRow: View {
    let title: String
    let valueLabel: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title); Spacer(); Text(valueLabel).monospacedDigit().modifier(SecondaryTextStyle()) }
            Group {
                if let step { Slider(value: $value, in: range, step: step) }
                else { Slider(value: $value, in: range) }
            }.accessibilityLabel(title).accessibilityValue(valueLabel)
        }
    }
}
