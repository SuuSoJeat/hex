import UIKit

/// The palette from the saved Khmer Layout Designer. A shifted key is colored for the
/// character it currently shows, so the same cap can change from a consonant to a digit.
@MainActor
enum KhmerismAppearance {
    struct Face {
        let fill: UIColor
        let ink: UIColor
    }

    static let plate = color(0x27212F)
    static let edge = color(0x3D3747)
    private static let ink = color(0xF1EFF5)
    static let action = Face(fill: color(0x51465E), ink: ink)
    static let selected = Face(fill: color(0xC7AAFF), ink: color(0x241A38))
    private static let consonant = Face(fill: color(0x42394B), ink: ink)
    private static let mark = Face(fill: color(0x294650), ink: color(0xE6F7FA))
    private static let independentVowel = Face(fill: color(0x36483F), ink: color(0xE4F3E8))
    private static let digit = Face(fill: color(0x543743), ink: color(0xF8E9ED))
    private static let other = Face(fill: color(0x43394D), ink: ink)

    static func face(for label: String) -> Face {
        guard let scalar = label.unicodeScalars.first else { return other }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return mark
        default: break
        }
        switch scalar.value {
        case 0x17D4...0x17D6, 0x17D7: return mark  // ។ ៕ ៖ ៗ
        case 0x17A5...0x17B3: return independentVowel
        case 0x17E0...0x17E9, 0x30...0x39: return digit
        case 0x1780...0x17A2: return consonant
        default: return other
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
