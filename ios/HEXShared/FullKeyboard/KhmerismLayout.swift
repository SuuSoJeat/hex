/// Hex's adaptation of the Khmerism letter rows, including the pair beside Space.
/// See ios/docs/acknowledgements.md for the layout's provenance. Shift swaps the main
/// and corner characters at each position.
nonisolated enum KhmerismLayout {
    struct Key {
        let text: String
        var shifted: String? = nil
        var alternate: String? = nil
        var shiftedAlternate: String? = nil
    }

    static let base: [[Key]] = [
        [
            Key(text: "ហ", shifted: "១", alternate: "១", shiftedAlternate: "ហ"),
            Key(text: "ណ", shifted: "២", alternate: "២", shiftedAlternate: "ណ"),
            Key(text: "ញ", shifted: "៣", alternate: "៣", shiftedAlternate: "ញ"),
            Key(text: "យ", shifted: "៤", alternate: "៤", shiftedAlternate: "យ"),
            Key(text: "វ", shifted: "៥", alternate: "៥", shiftedAlternate: "វ"),
            Key(text: "៉", shifted: "៊", alternate: "៊", shiftedAlternate: "៉"),
            Key(text: "ៅ", shifted: "ៈ", alternate: "ៈ", shiftedAlternate: "ៅ"),
            Key(text: "ៃ", shifted: "៏", alternate: "៏", shiftedAlternate: "ៃ"),
            Key(text: "ើ", shifted: "៍", alternate: "៍", shiftedAlternate: "ើ"),
            Key(text: "ឿ", shifted: "័", alternate: "័", shiftedAlternate: "ឿ"),
            Key(text: "ៀ", shifted: "៌", alternate: "៌", shiftedAlternate: "ៀ"),
        ],
        [
            Key(text: "ដ", shifted: "៦", alternate: "៦", shiftedAlternate: "ដ"),
            Key(text: "ត", shifted: "៧", alternate: "៧", shiftedAlternate: "ត"),
            Key(text: "ប", shifted: "៨", alternate: "៨", shiftedAlternate: "ប"),
            Key(text: "ក", shifted: "៩", alternate: "៩", shiftedAlternate: "ក"),
            Key(text: "ច", shifted: "០", alternate: "០", shiftedAlternate: "ច"),
            Key(text: "ោ", shifted: "ថ", alternate: "ថ", shiftedAlternate: "ោ"),
            Key(text: "ែ", shifted: "ធ", alternate: "ធ", shiftedAlternate: "ែ"),
            Key(text: "ិ", shifted: "ខ", alternate: "ខ", shiftedAlternate: "ិ"),
            Key(text: "ី", shifted: "ឃ", alternate: "ឃ", shiftedAlternate: "ី"),
            Key(text: "ឹ", shifted: "៎", alternate: "៎", shiftedAlternate: "ឹ"),
            Key(text: "ឺ", shifted: ".", alternate: ".", shiftedAlternate: "ឺ"),
        ],
        [
            Key(text: "ស", shifted: "ឬ", alternate: "ឬ", shiftedAlternate: "ស"),
            Key(text: "ន", shifted: "ឮ", alternate: "ឮ", shiftedAlternate: "ន"),
            Key(text: "ម", shifted: "ឯ", alternate: "ឯ", shiftedAlternate: "ម"),
            Key(text: "ង", shifted: "ឥ", alternate: "ឥ", shiftedAlternate: "ង"),
            Key(text: "ល", shifted: "ឧ", alternate: "ឧ", shiftedAlternate: "ល"),
            Key(text: "េ", shifted: "ឡ", alternate: "ឡ", shiftedAlternate: "េ"),
            Key(text: "រ", shifted: "ឲ", alternate: "ឲ", shiftedAlternate: "រ"),
            Key(text: "្", shifted: "ផ", alternate: "ផ", shiftedAlternate: "្"),
            Key(text: "ា", shifted: "ភ", alternate: "ភ", shiftedAlternate: "ា"),
            Key(text: "ះ", shifted: "ឆ", alternate: "ឆ", shiftedAlternate: "ះ"),
            Key(text: "ៗ", shifted: "ឈ", alternate: "ឈ", shiftedAlternate: "ៗ"),
        ],
        [
            Key(text: "ឌ", shifted: "ឫ", alternate: "ឫ", shiftedAlternate: "ឌ"),
            Key(text: "ទ", shifted: "ឭ", alternate: "ឭ", shiftedAlternate: "ទ"),
            Key(text: "ព", shifted: "ឰ", alternate: "ឰ", shiftedAlternate: "ព"),
            Key(text: "គ", shifted: "ឦ", alternate: "ឦ", shiftedAlternate: "គ"),
            Key(text: "ជ", shifted: "ឪ", alternate: "ឪ", shiftedAlternate: "ជ"),
            Key(text: "អ", shifted: "ឱ", alternate: "ឱ", shiftedAlternate: "អ"),
            Key(text: "ុ", shifted: "ឋ", alternate: "ឋ", shiftedAlternate: "ុ"),
            Key(text: "ូ", shifted: "ឍ", alternate: "ឍ", shiftedAlternate: "ូ"),
            Key(text: "ួ", shifted: "៛", alternate: "៛", shiftedAlternate: "ួ"),
        ],
        [
            Key(text: "ំ", shifted: "។", alternate: "។", shiftedAlternate: "ំ"),
            Key(text: "់", shifted: "?", alternate: "?", shiftedAlternate: "់"),
        ],
    ]

    /// Base positions that promote their shifted character immediately after coeng.
    static let afterCoeng = [
        "ោ": "ថ", "ែ": "ធ", "ិ": "ខ", "ី": "ឃ",
        "េ": "ឡ", "្": "ផ", "ា": "ភ", "ះ": "ឆ", "ៗ": "ឈ",
        "ុ": "ឋ", "ូ": "ឍ",
    ]

    // The English number and symbol rows use their usual keys. Only their footer adds these.
    static let numbersFooter = [Key(text: "។"), Key(text: "៕")]
    static let symbolsFooter = [Key(text: "។", alternate: "៙"), Key(text: "៖", alternate: "៚")]
}
