import SwiftUI
import UIKit

enum BudgetTheme {
    static let paper = Color(red: 0.030, green: 0.026, blue: 0.020)
    static let panel = Color(red: 0.108, green: 0.092, blue: 0.076)
    static let tile = Color(red: 0.165, green: 0.138, blue: 0.112)
    static let lifted = Color(red: 0.225, green: 0.185, blue: 0.145)
    static let ink = Color(red: 0.965, green: 0.930, blue: 0.850)
    static let secondaryInk = Color(red: 0.690, green: 0.635, blue: 0.540)
    static let line = Color.white.opacity(0.18)
    static let red = Color(hex: "FF453A")
    static let green = Color(hex: "30D158")
    static let yellow = Color(hex: "FFD60A")
    static let blue = Color(hex: "0A84FF")
    static let lightBlue = Color(hex: "64D2FF")
    static let black = ink
    static let brass = yellow
    static let teal = ink
    static let rust = red
    static let moss = green
    static let indigo = ink
    static let lotus = red
    static let saffron = yellow
    static let categoryInk = ink

    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [green, yellow, red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func stressTint(_ percent: Double) -> Color {
        signalTint(percent)
    }

    static func signalTint(_ percent: Double, inverse: Bool = false) -> Color {
        let clamped = max(0, min(1, percent))
        let stress = inverse ? 1 - clamped : clamped
        if stress < 0.66 {
            return mix(greenRGB, yellowRGB, amount: stress / 0.66)
        }
        return mix(yellowRGB, redRGB, amount: (stress - 0.66) / 0.34)
    }

    private static let redRGB = (1.0, 69.0 / 255.0, 58.0 / 255.0)
    private static let greenRGB = (48.0 / 255.0, 209.0 / 255.0, 88.0 / 255.0)
    private static let yellowRGB = (1.0, 214.0 / 255.0, 10.0 / 255.0)

    private static func mix(_ start: (Double, Double, Double), _ end: (Double, Double, Double), amount: Double) -> Color {
        let t = max(0, min(1, amount))
        return Color(
            red: start.0 + (end.0 - start.0) * t,
            green: start.1 + (end.1 - start.1) * t,
            blue: start.2 + (end.2 - start.2) * t
        )
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&integer)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch cleaned.count {
        case 6:
            red = (integer >> 16) & 0xFF
            green = (integer >> 8) & 0xFF
            blue = integer & 0xFF
        default:
            red = 0x66
            green = 0x66
            blue = 0x66
        }

        self.init(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

struct LedgerPanel<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(BudgetTheme.ink)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(BudgetTheme.secondaryInk)
                    }
                }
            }
            content
        }
        .padding(14)
        .background(BudgetTheme.panel, in: UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 18, bottomLeading: 7, bottomTrailing: 18, topTrailing: 7), style: .continuous))
        .overlay {
            LeatherGrain()
                .opacity(0.22)
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 18, bottomLeading: 7, bottomTrailing: 18, topTrailing: 7), style: .continuous))
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(BudgetTheme.rust)
                .frame(width: 34, height: 3)
                .padding(.leading, 14)
                .padding(.top, 8)
        }
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var footnote: String?
    var tint: Color
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(BudgetTheme.ink)
                .privacySensitive()
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
        }
    }
}

struct CategoryPill: View {
    let category: BudgetCategory?

    var body: some View {
        Label(category?.name ?? "Unassigned", systemImage: category?.symbol ?? "questionmark.circle")
            .font(.caption.weight(.medium))
            .foregroundStyle(category == nil ? Color.secondary : BudgetTheme.categoryInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((category == nil ? Color.secondary.opacity(0.10) : BudgetTheme.tile), in: Capsule())
    }
}

struct ProgressLine: View {
    var percent: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(BudgetTheme.line.opacity(0.65))
                Capsule()
                    .fill(BudgetTheme.signalTint(percent))
                    .frame(width: max(4, min(proxy.size.width, proxy.size.width * percent)))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Budget used")
        .accessibilityValue("\(Int(percent * 100)) percent")
    }
}

struct StatInstrument: View {
    var title: String
    var value: String
    var footnote: String
    var symbol: String
    var percent: Double
    var tint: Color
    var inverse = false
    var usesStressGradient = false

    private var fillPercent: Double {
        max(0, min(1, percent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(symbol)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BudgetTheme.ink)
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(BudgetTheme.ink)
                        .privacySensitive()
                }
                Spacer()
                Text("\(Int(fillPercent * 100))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(BudgetTheme.secondaryInk)
            }
            InstrumentBar(percent: fillPercent, tint: usesStressGradient ? BudgetTheme.signalTint(fillPercent, inverse: inverse) : tint, inverse: inverse)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(BudgetTheme.secondaryInk)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 286, height: 142, alignment: .topLeading)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: tint.opacity(0.16), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

struct InstrumentBar: View {
    var percent: Double
    var tint: Color? = nil
    var inverse = false

    private var fillPercent: Double {
        max(0, min(1, percent))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BudgetTheme.line.opacity(0.55))
                Capsule()
                    .fill(tint ?? BudgetTheme.signalTint(fillPercent, inverse: inverse))
                    .frame(width: max(8, proxy.size.width * fillPercent))
                    .blur(radius: 4)
                    .opacity(0.45)
                Capsule()
                    .fill(tint ?? BudgetTheme.signalTint(fillPercent, inverse: inverse))
                    .frame(width: max(8, proxy.size.width * fillPercent))
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(fillPercent * 100)) percent")
    }
}

struct DonutSlice: Identifiable {
    let id = UUID()
    let value: Decimal
    let color: Color
}

struct DonutChart: View {
    var slices: [DonutSlice]
    var lineWidth: CGFloat = 22

    private var total: Decimal {
        slices.reduce(.zero) { $0 + max(.zero, $1.value) }
    }

    var body: some View {
        Canvas { context, size in
            let diameter = min(size.width, size.height)
            let rect = CGRect(
                x: (size.width - diameter) / 2 + lineWidth / 2,
                y: (size.height - diameter) / 2 + lineWidth / 2,
                width: diameter - lineWidth,
                height: diameter - lineWidth
            )
            var start = Angle.degrees(-90)
            if total <= .zero {
                var path = Path()
                path.addEllipse(in: rect)
                context.stroke(path, with: .color(BudgetTheme.line), lineWidth: lineWidth)
            } else {
                for slice in slices where slice.value > .zero {
                    let degrees = 360 * (slice.value.doubleValue / total.doubleValue)
                    let end = start + .degrees(degrees)
                    var path = Path()
                    path.addArc(
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        radius: rect.width / 2,
                        startAngle: start,
                        endAngle: end,
                        clockwise: false
                    )
                    context.stroke(path, with: .color(slice.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    start = end
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    func budgetScreenBackground() -> some View {
        background(LeatherBackground())
    }

    func tactileListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(LeatherBackground())
    }
}

struct StatusGlyph: View {
    enum Tone {
        case positive
        case negative
        case attention
        case neutral

        var color: Color {
            switch self {
            case .positive: BudgetTheme.green
            case .negative: BudgetTheme.red
            case .attention: BudgetTheme.yellow
            case .neutral: BudgetTheme.ink
            }
        }

        var symbol: String {
            switch self {
            case .positive: "checkmark.circle.fill"
            case .negative: "exclamationmark.octagon.fill"
            case .attention: "exclamationmark.triangle.fill"
            case .neutral: "circle.fill"
            }
        }
    }

    var tone: Tone

    var body: some View {
        Image(systemName: tone.symbol)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tone.color)
            .accessibilityHidden(true)
    }
}

struct LeatherBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BudgetTheme.paper
            .overlay {
                LeatherGrain()
                    .opacity(0.58)
            }
            .ignoresSafeArea()
    }
}

struct LeatherGrain: View {
    var body: some View {
        Canvas { context, size in
            let verticalStep: CGFloat = 7
            let horizontalStep: CGFloat = 8
            var verticalX: CGFloat = -size.height
            while verticalX < size.width {
                var path = Path()
                path.move(to: CGPoint(x: verticalX, y: 0))
                path.addLine(to: CGPoint(x: verticalX + size.height * 0.34, y: size.height))
                context.stroke(path, with: .color(BudgetTheme.ink.opacity(0.12)), lineWidth: 0.75)
                verticalX += verticalStep
            }

            var horizontalY: CGFloat = 0
            while horizontalY < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: horizontalY))
                path.addLine(to: CGPoint(x: size.width, y: horizontalY + 2))
                context.stroke(path, with: .color(Color.white.opacity(0.22)), lineWidth: 0.6)
                horizontalY += horizontalStep
            }
        }
        .blendMode(.softLight)
    }
}
