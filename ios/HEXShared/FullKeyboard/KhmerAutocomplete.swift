import Foundation

/// Prefix completion and conservative spelling correction for Khmer text before the caret.
struct KhmerAutocomplete: Sendable {
    struct Candidate: Equatable, Sendable {
        let word: String
        /// The exact UTF-16 suffix to append to the text the user has already entered.
        let suffix: String
    }

    struct Correction: Equatable, Sendable {
        let typed: String
        let replacement: String
    }

    private struct Entry: Sendable {
        let word: String
        let units: [UInt16]
        let frequency: Int
    }

    private static let minimumPrefixLength = 2
    private static let contextLength = 96
    private static let coeng: UInt16 = 0x17D2

    // Orthographic examples from Table 5 of Kong et al., Khmer Spellchecking: A Holistic Approach
    // (https://arxiv.org/pdf/2511.09812#page=6). The ចំណុច example is from Chuon Nath's Khmer
    // dictionary, discussed in https://www.thmeythmey.com/index.php/detail/38623 and
    // https://www.thmeythmey.com/detail/80744.
    private static let reviewedMisspellings = [
        "សមាគុមន៍": "សមាគម",
        "ទន់ភ្លុន": "ទន់ភ្លន់",
        "កូមារភាព": "កុមារភាព",
        "បុំផ្ទុះ": "បំផ្ទុះ",
        "ចំនុច": "ចំណុច",
        "សមត្ថិភាព": "សមត្ថភាព",
    ].map { (units: Array($0.key.utf16), fix: Correction(typed: $0.key, replacement: $0.value)) }

    private let entries: [Entry]
    private let longestWord: Int

    static let bundled: KhmerAutocomplete? = {
        var url = Bundle.main.url(forResource: "km-autocomplete", withExtension: "tsv")
        if url == nil, let plugins = Bundle.main.builtInPlugInsURL,
           let keyboard = Bundle(url: plugins.appendingPathComponent("HEXKeyboard.appex")) {
            url = keyboard.url(forResource: "km-autocomplete", withExtension: "tsv")
        }
        guard let url, let wordlist = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let model = KhmerAutocomplete(wordlist: wordlist)
        return model.entries.isEmpty ? nil : model
    }()

    init(wordlist: String) {
        let entries = wordlist.split(whereSeparator: \.isNewline).compactMap { line -> Entry? in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let frequency = Int(fields[1]), frequency > 0 else { return nil }
            let units = Array(fields[0].utf16)
            guard let first = units.first, Self.beginsWord(first), units.allSatisfy(Self.isWordUnit),
                  units.last != Self.coeng else { return nil }
            return Entry(word: String(fields[0]), units: units, frequency: frequency)
        }
        self.entries = entries.sorted { $0.units.lexicographicallyPrecedes($1.units) }
        longestWord = entries.map(\.units.count).max() ?? 0
    }

    /// Khmer letters and marks to the right of the caret indicate that it may be inside a word.
    static func startsWithWordText(_ text: String?) -> Bool {
        guard let first = text?.utf16.first else { return false }
        return isWordUnit(first)
    }

    func suggestions(beforeInput: String?, limit: Int = 3) -> [Candidate] {
        guard let beforeInput, limit > 0, longestWord > Self.minimumPrefixLength else { return [] }
        let tail = beforeInput.utf16.reversed().prefix(Self.contextLength + 1).prefix(while: Self.isWordUnit)
        let run = Array(tail.prefix(Self.contextLength).reversed())
        let lastStart = run.count - Self.minimumPrefixLength
        guard lastStart >= 0 else { return [] }

        // A connected Khmer run can contain multiple words. Look for the longest active
        // prefix preceded by known words, and allow splits only between Khmer clusters.
        var wordStarts = Array(repeating: false, count: lastStart + 1)
        wordStarts[0] = Self.beginsWord(run[0])
        if tail.count > Self.contextLength {
            // The lookback may start mid-word. Recover at a plausible cluster boundary near
            // the cut, then still require known words between there and the live prefix.
            for start in 1...min(longestWord, lastStart) where Self.isBoundary(start, in: run) {
                wordStarts[start] = true
            }
        }

        for start in 0...lastStart where wordStarts[start] {
            let prefix = run[start...]
            if prefix.count <= longestWord {
                let first = lowerBound(of: prefix)
                if first < entries.count, entries[first].units.starts(with: prefix) {
                    // A finished word needs no completion. A shorter suffix could just be
                    // its final syllable, so stop once the longest live spelling is found.
                    if entries[first].units.count == prefix.count { return [] }
                    return completions(for: prefix, from: first, limit: limit)
                }
            }
            markWordEnds(from: start, in: run, into: &wordStarts)
        }
        return []
    }

    /// Returns a reviewed correction at an established Khmer word boundary. A full reading
    /// made of dictionary words takes precedence, including a compound typed without spaces.
    func correction(beforeInput: String?) -> Correction? {
        guard let beforeInput else { return nil }
        let tail = beforeInput.utf16.reversed().prefix(Self.contextLength + 1)
        let run = Array(tail.prefix(while: Self.isWordUnit).reversed())
        guard let first = run.first, Self.beginsWord(first), run.count <= Self.contextLength else { return nil }
        if let separator = tail.dropFirst(run.count).first,
           !Self.isSpellingBoundary(separator) { return nil }

        let candidates = Self.reviewedMisspellings.compactMap { units, fix -> (start: Int, fix: Correction)? in
            guard run.suffix(units.count).elementsEqual(units), contains(Array(fix.replacement.utf16)[...]) else {
                return nil
            }
            return (run.count - units.count, fix)
        }
        guard !candidates.isEmpty else { return nil }

        var wordStarts = Array(repeating: false, count: run.count + 1)
        wordStarts[0] = true
        for start in run.indices where wordStarts[start] {
            markWordEnds(from: start, in: run, into: &wordStarts)
        }
        guard !wordStarts[run.count] else { return nil }
        let reachable = candidates.filter { wordStarts[$0.start] }
        return reachable.count == 1 ? reachable.first?.fix : nil
    }

    private func markWordEnds(from start: Int, in run: [UInt16], into wordStarts: inout [Bool]) {
        let lastEnd = min(start + longestWord, wordStarts.count - 1)
        guard start < lastEnd else { return }
        for end in (start + 1)...lastEnd where end == run.count || Self.isBoundary(end, in: run) {
            if contains(run[start..<end]) { wordStarts[end] = true }
        }
    }

    private func contains(_ spelling: ArraySlice<UInt16>) -> Bool {
        let index = lowerBound(of: spelling)
        return index < entries.count && entries[index].units.elementsEqual(spelling)
    }

    private func completions(for prefix: ArraySlice<UInt16>, from first: Int, limit: Int) -> [Candidate] {
        let matches = entries[first...].prefix { $0.units.starts(with: prefix) }
        return matches.sorted { left, right in
            if left.frequency != right.frequency { return left.frequency > right.frequency }
            return left.units.lexicographicallyPrecedes(right.units)
        }.prefix(limit).map { entry in
            Candidate(word: entry.word, suffix: String(decoding: entry.units.dropFirst(prefix.count), as: UTF16.self))
        }
    }

    private func lowerBound(of spelling: ArraySlice<UInt16>) -> Int {
        var lower = 0
        var upper = entries.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if entries[middle].units.lexicographicallyPrecedes(spelling) {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private static func beginsWord(_ unit: UInt16) -> Bool { (0x1780...0x17B3).contains(unit) }

    // All supported Khmer characters are in the BMP. Compare code units so a coeng or
    // combining vowel can be the last part of a valid prefix before its cluster is complete.
    private static func isWordUnit(_ unit: UInt16) -> Bool {
        (0x1780...0x17D3).contains(unit) || unit == 0x17DD || unit == 0x200C || unit == 0x200D
    }

    private static func isBoundary(_ index: Int, in run: [UInt16]) -> Bool {
        let previous = run[index - 1]
        return beginsWord(run[index]) && previous != coeng && previous != 0x200C && previous != 0x200D
    }

    private static func isSpellingBoundary(_ unit: UInt16) -> Bool {
        switch unit {
        case 0x200B, 0x17D4...0x17D6, 0x17D8...0x17DA: return true
        default: return Unicode.Scalar(unit).map(CharacterSet.whitespacesAndNewlines.contains) ?? false
        }
    }
}
