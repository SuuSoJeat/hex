/// The standard Khmer key arrangement observed on the iOS 27.2 keyboard.
nonisolated enum KhmerLayout {
    struct Key {
        let text: String
        var shifted: String? = nil
        var alternate: String? = nil
        var shiftedAlternate: String? = nil
    }

    static let letters = [
        row("១ ២ ៣ ៤ ៥ ៦ ៧ ៨ ៩ ០ ឥ ឲ", shifted: "! ៗ \" ៛ % ៍ ័ ៏ ឰ ឳ ៌ ៎"),
        row("ឆ ឹ េ រ ត យ ុ ិ ោ ផ ៀ ឪ", shifted: "ឈ ឺ ែ ឬ ទ ួ ូ ី ៅ ភ ឿ ឧ"),
        row("ា ស ដ ថ ង ហ ្ ក ល ើ ់ ឭ", shifted: "ឫ ៃ ឌ ធ អ ះ ញ គ ឡ ៖ ៉ ឮ"),
        row("ឋ ខ ច វ ប ន ម ឦ ។ ៊", shifted: "ឍ ឃ ជ ៈ ព ណ ំ ឱ ៕ ឯ"),
    ]

    static let numbers = [
        glyphs("1 2 3 4 5 6 7 8 9 0"),
        glyphs("« » @ ៑ ៛ / ៙ ៚ ( )"),
        glyphs("ឩ ឝ ឞ ? !"),
    ]

    static let symbols = [
        glyphs("[ ] { } # % ^ * + ="),
        glyphs("- _ : ; < > $ £ € •"),
        glyphs(". , ' ? !"),
    ]

    /// Holding a Khmerism letter types the character on its other layer.
    static func row(_ base: String, shifted: String, holdForOtherLayer: Bool = false) -> [Key] {
        zip(glyphs(base), glyphs(shifted)).map { main, shift in
            Key(text: main, shifted: shift, alternate: holdForOtherLayer ? shift : nil,
                shiftedAlternate: holdForOtherLayer ? main : nil)
        }
    }

    private static func glyphs(_ row: String) -> [String] {
        // A combining mark can share a Swift Character with the preceding separator.
        row.unicodeScalars.split(separator: " ").map { String(String.UnicodeScalarView($0)) }
    }
}
