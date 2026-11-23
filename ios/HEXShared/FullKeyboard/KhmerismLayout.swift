/// Hex's adaptation of the Khmerism letter rows, including the pair beside Space.
/// See ios/docs/acknowledgements.md for the layout's provenance. Shift swaps the main
/// and corner characters at each position.
nonisolated enum KhmerismLayout {
    private static func row(_ main: String, shifted: String) -> [KhmerLayout.Key] {
        KhmerLayout.row(main, shifted: shifted, holdForOtherLayer: true)
    }

    static let base: [[KhmerLayout.Key]] = [
        row("ហ ណ ញ យ វ ៉ ៅ ៃ ើ ឿ ៀ", shifted: "១ ២ ៣ ៤ ៥ ៊ ៈ ៏ ៍ ័ ៌"),
        row("ដ ត ប ក ច ោ ែ ិ ី ឹ ឺ", shifted: "៦ ៧ ៨ ៩ ០ ថ ធ ខ ឃ ៎ ."),
        row("ស ន ម ង ល េ រ ្ ា ះ ៗ", shifted: "ឬ ឮ ឯ ឥ ឧ ឡ ឲ ផ ភ ឆ ឈ"),
        row("ឌ ទ ព គ ជ អ ុ ូ ួ", shifted: "ឫ ឭ ឰ ឦ ឪ ឱ ឋ ឍ ៛"),
        row("ំ ់", shifted: "។ ?"),
    ]

    /// Base positions that promote their shifted character immediately after coeng.
    static let afterCoeng = [
        "ោ": "ថ", "ែ": "ធ", "ិ": "ខ", "ី": "ឃ",
        "េ": "ឡ", "្": "ផ", "ា": "ភ", "ះ": "ឆ", "ៗ": "ឈ",
        "ុ": "ឋ", "ូ": "ឍ",
    ]

    // The English number and symbol rows use their usual keys. Only their footer adds these.
    static let numbersFooter = [KhmerLayout.Key(text: "។"), KhmerLayout.Key(text: "៕")]
    static let symbolsFooter = [KhmerLayout.Key(text: "។", alternate: "៙"), KhmerLayout.Key(text: "៖", alternate: "៚")]
}
