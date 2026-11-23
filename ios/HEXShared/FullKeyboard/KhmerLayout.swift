/// The standard Khmer key arrangement observed on the iOS 27.2 keyboard.
nonisolated enum KhmerLayout {
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

    private static func row(_ base: String, shifted: String) -> [KhmerismLayout.Key] {
        zip(glyphs(base), glyphs(shifted)).map { KhmerismLayout.Key(text: $0, shifted: $1) }
    }

    private static func glyphs(_ row: String) -> [String] {
        // A combining mark can share a Swift Character with the preceding separator.
        row.unicodeScalars.split(separator: " ").map { String(String.UnicodeScalarView($0)) }
    }
}
