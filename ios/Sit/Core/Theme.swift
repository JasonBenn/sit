import SwiftUI

enum Theme {
    // Background colors
    static let bg = Color(hex: "111110")
    static let card = Color(hex: "1C1B19")
    static let cardAlt = Color(hex: "252422")
    static let border = Color(hex: "2A2825")

    // Text colors
    static let text = Color(hex: "E8E4DE")
    static let textMuted = Color(hex: "7A756E")
    static let textDim = Color(hex: "5A5650")

    // Accent colors
    static let sage = Color(hex: "5F8566")
    static let sageText = Color(hex: "8DB897")
    static let amber = Color(hex: "9A7040")

    // Font helpers
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .light ? "CormorantGaramond-Light" : "CormorantGaramond-Regular"
        return .custom(name, size: size)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .medium ? "Outfit-Medium" : "Outfit-Regular"
        return .custom(name, size: size)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
