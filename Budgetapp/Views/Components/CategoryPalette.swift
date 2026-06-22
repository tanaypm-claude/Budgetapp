import SwiftUI

/// Curated colours and icons offered when creating categories/projects, chosen
/// to sit well on the warm paper palette.
enum CategoryPalette {
    static let colors: [String] = [
        "#C97C3C", "#B24A3D", "#C25E7A", "#9C6B9E", "#5E7CE2",
        "#4C8CB5", "#6BB0A4", "#6FA86B", "#4F9D69", "#D2A24C",
        "#8A8170", "#7A6E63"
    ]

    static let symbols: [String] = [
        "fork.knife", "cart", "car.fill", "house.fill", "bolt.fill",
        "bag.fill", "rectangle.stack.badge.play", "cross.case.fill",
        "gift.fill", "airplane", "fuelpump.fill", "pawprint.fill",
        "gamecontroller.fill", "book.fill", "graduationcap.fill",
        "dumbbell.fill", "tram.fill", "wifi", "phone.fill", "creditcard",
        "banknote", "heart.fill", "cup.and.saucer.fill", "tag"
    ]
}

/// A wrapping grid of colour swatches.
struct ColorSwatchPicker: View {
    @Binding var selection: String
    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryPalette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().strokeBorder(Theme.ink, lineWidth: selection == hex ? 2.5 : 0)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(selection == hex ? 1 : 0)
                    )
                    .onTapGesture { selection = hex; Haptics.selection() }
                    .accessibilityLabel("Colour")
                    .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// A wrapping grid of SF Symbols tinted with the chosen colour.
struct SymbolPicker: View {
    @Binding var selection: String
    let colorHex: String
    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryPalette.symbols, id: \.self) { symbol in
                let isSelected = selection == symbol
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(hex: colorHex).opacity(0.22) : Theme.surfaceSunken)
                    .frame(height: 44)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? Color(hex: colorHex) : Theme.inkSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(hex: colorHex), lineWidth: isSelected ? 1.5 : 0)
                    )
                    .onTapGesture { selection = symbol; Haptics.selection() }
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
