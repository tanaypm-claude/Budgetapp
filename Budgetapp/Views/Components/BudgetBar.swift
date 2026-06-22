import SwiftUI

/// A horizontal progress rule that fills toward a budget and turns to the
/// warning/negative tint as it approaches/exceeds the limit.
struct BudgetBar: View {
    /// 0...1+ (values over 1 are clamped visually but tinted as overspend).
    let fraction: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 8

    private var clamped: Double { min(max(fraction, 0), 1) }

    private var fillColor: Color {
        if fraction > 1.0 { return Theme.negative }
        if fraction >= 0.85 { return Theme.warning }
        return tint
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceSunken)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(geo.size.width * clamped, fraction > 0 ? 4 : 0))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
