import SwiftUI

/// The app's visual language: a calm "annotated ledger" palette — warm paper in
/// light mode, deep ink in dark mode — with a single confident accent and a few
/// signal colors. Centralised so the whole app stays coherent.
enum Theme {

    // MARK: Surfaces
    /// App background (the "paper").
    static let paper = Color.adaptive(
        light: Color(hex: "#F4EFE6"),
        dark: Color(hex: "#15161A")
    )
    /// Raised surface for rows, cards, fields.
    static let surface = Color.adaptive(
        light: Color(hex: "#FBF8F1"),
        dark: Color(hex: "#202228")
    )
    /// A slightly recessed surface used for secondary panels.
    static let surfaceSunken = Color.adaptive(
        light: Color(hex: "#EDE6D8"),
        dark: Color(hex: "#1A1B20")
    )
    /// Hairline rules, like ledger lines.
    static let hairline = Color.adaptive(
        light: Color(hex: "#D8CDBA"),
        dark: Color(hex: "#34373F")
    )

    // MARK: Ink (text)
    static let ink = Color.adaptive(
        light: Color(hex: "#26221C"),
        dark: Color(hex: "#ECE7DC")
    )
    static let inkSecondary = Color.adaptive(
        light: Color(hex: "#6B6557"),
        dark: Color(hex: "#9B968B")
    )
    static let inkFaint = Color.adaptive(
        light: Color(hex: "#9A9384"),
        dark: Color(hex: "#6A675F")
    )

    // MARK: Accent + signals
    static let accent = Color.adaptive(
        light: Color(hex: "#C9733C"),
        dark: Color(hex: "#E69459")
    )
    static let positive = Color.adaptive(
        light: Color(hex: "#3E8E63"),
        dark: Color(hex: "#5FBE89")
    )
    static let negative = Color.adaptive(
        light: Color(hex: "#B24A3D"),
        dark: Color(hex: "#E0796B")
    )
    static let warning = Color.adaptive(
        light: Color(hex: "#C28A2A"),
        dark: Color(hex: "#E0B255")
    )

    // MARK: Metrics
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}
