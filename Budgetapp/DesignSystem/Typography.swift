import SwiftUI

/// Type styles. Body/labels use the rounded system face for a tactile feel;
/// numbers use monospaced digits so figures align like a ledger. All sizes are
/// relative so Dynamic Type keeps working.
extension Font {
    /// Large screen titles.
    static func ledgerTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.semibold) }
    /// Section headers.
    static func ledgerHeadline() -> Font { .system(.headline, design: .rounded) }
    /// Standard body.
    static func ledgerBody() -> Font { .system(.body, design: .rounded) }
    /// Secondary / caption text.
    static func ledgerCaption() -> Font { .system(.footnote, design: .rounded) }

    /// Monospaced figures for amounts.
    static func ledgerNumber(_ style: Font.TextStyle = .body, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

extension View {
    /// Apply monospaced digits to any text showing figures (keeps alignment even
    /// with the default font).
    func ledgerDigits() -> some View {
        self.monospacedDigit()
    }
}
