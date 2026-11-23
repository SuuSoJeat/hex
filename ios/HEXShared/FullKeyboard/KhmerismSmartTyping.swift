import Foundation

nonisolated enum KhmerismSmartTyping {
    static let adaptiveSigns = [
        "ក": "៏", "ដ": "៏", "ន": "៍", "ស": "៊", "ហ": "៊", "អ": "៊", "ប": "៉",
    ]
    private static let repeatedVowels = ["ា": "ំ", "េ": "ះ", "ោ": "ះ"]
    static let doubleTapWindow: TimeInterval = 0.35
    static let coeng: UInt16 = 0x17D2

    static func isBase(_ unit: UInt16) -> Bool { (0x1780...0x17B3).contains(unit) }

    private static func isVowel(_ unit: UInt16) -> Bool { (0x17B6...0x17C5).contains(unit) }

    private static func isShifter(_ unit: UInt16) -> Bool { (0x17C9...0x17CA).contains(unit) }

    private static func isFinalSign(_ unit: UInt16) -> Bool {
        (0x17C6...0x17C8).contains(unit) || unit == 0x17CB
            || (0x17CD...0x17D1).contains(unit) || unit == 0x17DD
    }

    static func isMark(_ unit: UInt16) -> Bool {
        isVowel(unit) || isShifter(unit) || isFinalSign(unit) || unit == coeng || unit == 0x17CC
    }

    static func startsVowelPair(_ text: String) -> Bool { repeatedVowels[text] != nil }

    /// A rewrite of the current, key-entered syllable. Nil means insert the key as typed.
    static func replacement(adding text: String, to syllable: String, afterTap: Bool, repeatsTap: Bool) -> String? {
        if text == "ំ", syllable == "ញ", afterTap { return "ខ្ញុំ" }
        if repeatsTap, let ending = repeatedVowels[text] { return syllable + ending }

        var units = Array(syllable.utf16)
        guard let base = units.first, isBase(base), units.last != coeng, let incoming = text.utf16.first else { return nil }

        // The original shortcut lets an explicit asda take the place of the first sign.
        if text == "៏", units.count == 2, [0x1780, 0x178A, 0x1793].contains(base), // ក, ដ, ន
           [0x17C9, 0x17CD, 0x17CF].contains(units[1]) {
            return String(decoding: units.prefix(1), as: UTF16.self) + text
        }

        // Unicode 17, §16.4: encode a register shifter directly after the base, before coeng
        // pairs and vowels. A second explicit shifter chooses the register.
        if isShifter(incoming), (0x1780...0x17A2).contains(base) {
            units.removeAll(where: isShifter)
            units.insert(incoming, at: 1)
        } else if isVowel(incoming), !units.contains(where: isVowel),
                  let beforeFinal = units.lastIndex(where: { !isFinalSign($0) }) {
            units.insert(incoming, at: beforeFinal + 1)
        } else {
            return nil
        }
        let ordered = String(decoding: units, as: UTF16.self)
        return ordered == syllable + text ? nil : ordered
    }
}
