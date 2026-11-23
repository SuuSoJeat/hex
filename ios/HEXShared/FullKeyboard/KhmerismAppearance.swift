import CoreText
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

    static func containsKhmer(_ text: String) -> Bool {
        text.utf16.contains { (0x1780...0x17FF).contains($0) }
    }

    static func font(for label: String, size: CGFloat) -> UIFont {
        if containsKhmer(label),
           let font = UIFont(name: "KhmerMN", size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }

    struct Legend {
        let line: CTLine
        let bounds: CGRect
        let scale: CGFloat
        let origin: CGPoint

        func draw(in context: CGContext) {
            context.saveGState()
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: scale, y: -scale)
            context.textMatrix = .identity
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    static func legends(
        main: String, alternate: String?, in frame: CGRect, mainSize: CGFloat, ink: UIColor
    ) -> (main: Legend?, alternate: Legend?) {
        let padding = min(3, frame.width * 0.12, frame.height * 0.12)
        let content = frame.insetBy(dx: padding, dy: padding)
        let cornerHeight = min(11, content.height * 0.3)
        let corner = CGRect(
            x: content.midX, y: content.minY, width: content.width / 2, height: cornerHeight
        )
        let secondary = alternate.flatMap {
            legend($0, in: corner, size: min(10, cornerHeight), ink: ink.withAlphaComponent(0.8), corner: true)
        }
        var primary = content
        if secondary != nil {
            // Give corner labels a consistent band so even split vowels have space beneath them.
            let reserved = cornerHeight + 2
            primary.origin.y += reserved
            primary.size.height -= reserved
        }
        return (legend(main, in: primary, size: mainSize, ink: ink, rise: secondary == nil ? 0 : 2), secondary)
    }

    private static func legend(
        _ label: String, in frame: CGRect, size: CGFloat, ink: UIColor, corner: Bool = false, rise: CGFloat = 0
    ) -> Legend? {
        guard size > 0, frame.width > 0, frame.height > 0 else { return nil }
        let text = NSAttributedString(string: label, attributes: [.font: font(for: label, size: size), .foregroundColor: ink])
        let line = CTLineCreateWithAttributedString(text)
        // Khmer marks can extend outside the font's advance and above or below its line box.
        let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard !inkBounds.isEmpty else { return nil }
        let scale = min(1, frame.width / inkBounds.width, frame.height / inkBounds.height)
        let width = inkBounds.width * scale
        let height = inkBounds.height * scale
        let bounds = CGRect(
            x: corner ? frame.maxX - width : frame.midX - width / 2,
            y: corner ? frame.minY : max(frame.minY, frame.midY - height / 2 - rise),
            width: width, height: height
        )
        let origin = CGPoint(x: bounds.minX - inkBounds.minX * scale, y: bounds.minY + inkBounds.maxY * scale)
        return Legend(line: line, bounds: bounds, scale: scale, origin: origin)
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
