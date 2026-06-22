import SwiftUI

/// A rounded tile showing a category's SF Symbol over its tint. Used in lists
/// and pickers so categories are recognisable at a glance.
struct CategoryGlyph: View {
    let symbol: String
    let colorHex: String
    var size: CGFloat = 38

    var body: some View {
        let color = Color(hex: colorHex)
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(color.opacity(0.30), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
