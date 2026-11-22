import UIKit

/// The final Khmerism design in the keyboard's effective light or dark appearance.
@MainActor
enum KhmerismAppearance {
    struct Face {
        let fill: UIColor
        let ink: UIColor
    }

    private struct Palette {
        let mark: Face
        let independentVowel: Face
        let digit: Face
    }

    private static let dark = Palette(
        mark: Face(fill: color(0x294650), ink: color(0xE6F7FA)),
        independentVowel: Face(fill: color(0x36483F), ink: color(0xE4F3E8)),
        digit: Face(fill: color(0x543743), ink: color(0xF8E9ED))
    )
    private static let light = Palette(
        mark: Face(fill: color(0xBDE0E7), ink: color(0x163741)),
        independentVowel: Face(fill: color(0xCFE3D3), ink: color(0x203B29)),
        digit: Face(fill: color(0xEBC9D4), ink: color(0x482738))
    )
    /// Classify the visible character so a shifted cap can change color.
    static func face(for label: String, isDark: Bool) -> Face? {
        let palette = isDark ? dark : light
        guard let scalar = label.unicodeScalars.first else { return nil }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return palette.mark
        default: break
        }
        switch scalar.value {
        case 0x17D4...0x17D7: return palette.mark  // ។ ៕ ៖ ៗ
        case 0x17A5...0x17B3: return palette.independentVowel
        case 0x17E0...0x17E9: return palette.digit
        default: return nil
        }
    }

    static func font(for label: String, size: CGFloat) -> UIFont {
        if label.unicodeScalars.contains(where: { (0x1780...0x17FF).contains($0.value) }),
           let font = UIFont(name: "KhmerMN", size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: 1
        )
    }
}
