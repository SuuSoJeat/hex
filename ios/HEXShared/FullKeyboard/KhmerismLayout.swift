/// Character rows from the saved Khmer Layout Designer. The last row holds the two
/// characters next to Space; Shift and the other action keys are laid out separately.
nonisolated enum KhmerismLayout {
    struct Key {
        let text: String
        let shifted: String?
        let alternate: String?
        let shiftedAlternate: String?

        init(text: String, shifted: String? = nil, alternate: String? = nil, shiftedAlternate: String? = nil) {
            self.text = text
            self.shifted = shifted
            self.alternate = alternate
            self.shiftedAlternate = shiftedAlternate
        }
    }

    static let base: [[Key]] = [
        [
            Key(text: "ហ", shifted: "១", alternate: "១", shiftedAlternate: "ហ"),
            Key(text: "ណ", shifted: "២", alternate: "២", shiftedAlternate: "ណ"),
            Key(text: "ញ", shifted: "៣", alternate: "៣", shiftedAlternate: "ញ"),
            Key(text: "យ", shifted: "៤", alternate: "៤", shiftedAlternate: "យ"),
            Key(text: "វ", shifted: "៥", alternate: "៥", shiftedAlternate: "វ"),
            Key(text: "៉", shifted: "៛", alternate: "៊", shiftedAlternate: "ួ"),
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
            Key(text: "ោ", shifted: "ខ", alternate: "ថ", shiftedAlternate: "ិ"),
            Key(text: "ែ", shifted: "ឃ", alternate: "ធ", shiftedAlternate: "ី"),
            Key(text: "ិ", shifted: "ថ", alternate: "ខ", shiftedAlternate: "ោ"),
            Key(text: "ី", shifted: "ធ", alternate: "ឃ", shiftedAlternate: "ែ"),
            Key(text: "ឹ", shifted: "៕", alternate: "៎", shiftedAlternate: "ឈ"),
            Key(text: "ឺ", shifted: "?", alternate: ".", shiftedAlternate: "់"),
        ],
        [
            Key(text: "ស", shifted: "ឥ", alternate: "ឬ", shiftedAlternate: "ង"),
            Key(text: "ន", shifted: "ឧ", alternate: "ឮ", shiftedAlternate: "ល"),
            Key(text: "ម", shifted: "ឯ", alternate: "ឯ", shiftedAlternate: "ម"),
            Key(text: "ង", shifted: "ឬ", alternate: "ឥ", shiftedAlternate: "ស"),
            Key(text: "ល", shifted: "ឮ", alternate: "ឧ", shiftedAlternate: "ន"),
            Key(text: "េ", shifted: "ឍ", alternate: "ឦ", shiftedAlternate: "្"),
            Key(text: "រ", shifted: "៊", alternate: "ឲ", shiftedAlternate: "៉"),
            Key(text: "្", shifted: "ភ", alternate: "ឍ", shiftedAlternate: "ា"),
            Key(text: "ា", shifted: "ឋ", alternate: "ភ", shiftedAlternate: "ះ"),
            Key(text: "ះ", shifted: "ឈ", alternate: "ឋ", shiftedAlternate: "ៗ"),
            Key(text: "ៗ", shifted: "។", alternate: "ឈ", shiftedAlternate: "ំ"),
        ],
        [
            Key(text: "ឌ", shifted: "ឦ", alternate: "ឫ", shiftedAlternate: "គ"),
            Key(text: "ទ", shifted: "ឩ", alternate: "ឭ"),
            Key(text: "ព", shifted: "ឪ", alternate: "ឩ", shiftedAlternate: "អ"),
            Key(text: "គ", shifted: "ឫ", alternate: "ឦ", shiftedAlternate: "ឌ"),
            Key(text: "ជ", shifted: "ឭ", alternate: "ឳ", shiftedAlternate: "ទ"),
            Key(text: "អ", shifted: "ឳ", alternate: "ឪ", shiftedAlternate: "ជ"),
            Key(text: "ុ", shifted: "ផ", alternate: "ផ", shiftedAlternate: "ុ"),
            Key(text: "ូ", shifted: "ឡ", alternate: "ឡ", shiftedAlternate: "ូ"),
            Key(text: "ួ", shifted: "ឲ", alternate: "វ", shiftedAlternate: "វ"),
        ],
        [
            Key(text: "ំ", shifted: ".", alternate: "។", shiftedAlternate: "ឺ"),
            Key(text: "់", shifted: ":", alternate: "?"),
        ],
    ]

    static let numbers: [[Key]] = [
        ["១", "២", "៣", "៤", "៥", "៦", "៧", "៨", "៩", "០", "៛"],
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "%"],
        ["+", "−", "×", "÷", "=", "/", "(", ")", "[", "]", "@"],
        ["#", "&", "€", "$", "£", "¥", "*", "_", "~"],
        ["។", "៕"],
    ].map { row in row.map { Key(text: $0) } }

    static let symbols: [[Key]] = [
        ["!", "?", ":", ";", "“", "”", "‘", "’", "«", "»", "…"],
        ["{", "}", "<", ">", "^", "|", "~", "#", "*", "_", "="],
        ["៙", "៚", "៘", "៖", "•", "–", "—", "§", "©", "®", "™"],
        ["\\", "@", "$", "%", "+", "−", "×", "÷", "/"],
        [".", ","],
    ].map { row in row.map { Key(text: $0) } }
}
