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
        let automaticallyApplies: Bool
        let rankedByTapPosition: Bool
        let dictionaryAlternative: String?

        init(typed: String, replacement: String, automaticallyApplies: Bool = true,
             rankedByTapPosition: Bool = false, dictionaryAlternative: String? = nil) {
            self.typed = typed
            self.replacement = replacement
            self.automaticallyApplies = automaticallyApplies
            self.rankedByTapPosition = rankedByTapPosition
            self.dictionaryAlternative = dictionaryAlternative
        }

        func selecting(_ word: String) -> Self? {
            if word == replacement { return self }
            guard word == dictionaryAlternative else { return nil }
            return Self(typed: typed, replacement: word, automaticallyApplies: false)
        }
    }

    private struct Entry: Sendable {
        let word: String
        let units: [UInt16]
        let frequency: Int
    }

    private struct PersonalLexicon {
        let terms: [[UInt16]]
        let words: Set<[UInt16]>
        let longestWord: Int

        init(_ spellings: [String]) {
            var seen = Set<[UInt16]>()
            terms = spellings.compactMap { spelling in
                let units = Array(spelling.utf16)
                guard let first = units.first, KhmerAutocomplete.beginsWord(first),
                      seen.insert(units).inserted else { return nil }
                return units
            }
            words = Set(terms.filter { $0.allSatisfy(KhmerAutocomplete.isWordUnit) && KhmerAutocomplete.hasCompleteClusters($0[...]) })
            longestWord = words.map(\.count).max() ?? 0
        }
    }

    private static let minimumDuplicateMarkLength = 3
    private static let minimumSpellingLength = 4
    // Require the tap to be meaningfully closer to the alternative before changing the strip.
    private static let minimumSubstitutionGain = 0.65
    private static let minimumCoengCorrectionFrequency = 1_000
    private static let contextLength = 96
    private static let coeng: UInt16 = 0x17D2
    private static let dependentVowels: ClosedRange<UInt16> = 0x17B6...0x17C5
    private static let spellingAlphabet = Array(UInt16(0x1780)...0x17B3) + Array(UInt16(0x17B6)...0x17D2) + [0x17DD]

    private let entries: [Entry]
    private let longestWord: Int
    let expandedWords: TypingDecoderModel?

    static let bundled: KhmerAutocomplete? = {
        var url = Bundle.main.url(forResource: "km-autocomplete", withExtension: "tsv")
        if url == nil, let plugins = Bundle.main.builtInPlugInsURL,
           let keyboard = Bundle(url: plugins.appendingPathComponent("HEXKeyboard.appex")) {
            url = keyboard.url(forResource: "km-autocomplete", withExtension: "tsv")
        }
        guard let url, let wordlist = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let supplementURL = url.deletingLastPathComponent().appendingPathComponent("km-buddhist.txt")
        let supplement = (try? String(contentsOf: supplementURL, encoding: .utf8)) ?? ""
        let expandedURL = url.deletingLastPathComponent().appendingPathComponent("km-expanded.hextm")
        let model = KhmerAutocomplete(wordlist: wordlist, supplementalWords: supplement,
                                     expandedWords: TypingDecoderModel(url: expandedURL))
        return model.entries.isEmpty ? nil : model
    }()

    init(wordlist: String, supplementalWords: String = "", expandedWords: TypingDecoderModel? = nil) {
        self.expandedWords = expandedWords?.language == "km" ? expandedWords : nil
        var entries = wordlist.split(whereSeparator: \.isNewline).compactMap { line -> Entry? in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let frequency = Int(fields[1]), frequency > 0 else { return nil }
            let units = Array(fields[0].utf16)
            guard let first = units.first, Self.beginsWord(first), units.allSatisfy(Self.isWordUnit),
                  units.last != Self.coeng else { return nil }
            return Entry(word: String(fields[0]), units: units, frequency: frequency)
        }
        // Uncounted Pali and Sanskrit spellings are valid as typed and can complete
        // a prefix. A measured Khmer word always ranks ahead of an uncounted one.
        var known = Set(entries.map(\.word))
        for line in supplementalWords.split(whereSeparator: \.isNewline) {
            let word = String(line)
            let units = Array(word.utf16)
            guard let first = units.first, Self.beginsWord(first), units.allSatisfy(Self.isWordUnit),
                  units.last != Self.coeng, known.insert(word).inserted else { continue }
            entries.append(Entry(word: word, units: units, frequency: 0))
        }
        self.entries = entries.sorted { $0.units.lexicographicallyPrecedes($1.units) }
        longestWord = entries.map(\.units.count).max() ?? 0
    }

    /// Khmer letters and marks to the right of the caret indicate that it may be inside a word.
    static func startsWithWordText(_ text: String?) -> Bool {
        guard let first = text?.utf16.first else { return false }
        return isWordUnit(first)
    }

    static func endsWithWordText(_ text: Substring) -> Bool {
        text.utf16.last.map(isWordUnit) ?? false
    }

    /// A space or zero-width space marks the previous word even after the next word has begun.
    func separatedContext(in before: String, personalWords: [String]) -> (word: String, prefix: String)? {
        let prefixLength = before.utf16.reversed().prefix(Self.contextLength + 1).prefix(while: Self.isWordUnit).count
        guard prefixLength <= Self.contextLength else { return nil }
        let start = before.utf16.index(before.endIndex, offsetBy: -prefixLength)
        var preceding = before[..<start]
        while preceding.last == " " || preceding.last == "\u{200B}" { preceding = preceding.dropLast() }
        guard preceding.endIndex != start, let word = wordSuffix(
            in: preceding, personalWords: personalWords, includeExpanded: prefixLength != 1
        ) else { return nil }
        return (word, String(before[start...]))
    }

    /// The longest known final word that starts at a boundary reached by whole words.
    /// If the run is incomplete or extends beyond the lookback, leave word deletion alone.
    func wordSuffix(in before: Substring, personalWords: [String] = [], includeExpanded: Bool = true) -> String? {
        let tail = before.utf16.reversed().prefix(Self.contextLength + 1)
        let run = Array(tail.prefix(while: Self.isWordUnit).reversed())
        guard let first = run.first, Self.beginsWord(first),
              run.count <= Self.contextLength, Self.hasCompleteClusters(run[...]) else { return nil }
        let personal = PersonalLexicon(personalWords)
        var wordStarts = Array(repeating: false, count: run.count + 1)
        wordStarts[0] = true
        for start in run.indices where wordStarts[start] {
            let candidate = run[start...]
            if contains(candidate, personal: personal) || (includeExpanded && isExpandedWord(candidate)) {
                return String(decoding: candidate, as: UTF16.self)
            }
            markWordEnds(from: start, in: run, personal: personal, expanded: includeExpanded ? expandedWords : nil,
                         into: &wordStarts)
        }
        return nil
    }

    func suggestions(
        beforeInput: String?, limit: Int = 3, personalWords: [String] = [],
        mayOffer: (String) -> Bool = { _ in true }
    ) -> [Candidate] {
        guard let beforeInput, limit > 0 else { return [] }
        let personal = PersonalLexicon(personalWords)
        let tail = beforeInput.utf16.reversed().prefix(Self.contextLength + 1).prefix(while: Self.isWordUnit)
        let run = Array(tail.prefix(Self.contextLength).reversed())
        guard !run.isEmpty else { return [] }

        // A connected Khmer run can contain multiple words. Look for the longest active
        // prefix preceded by known words, and allow splits only between Khmer clusters.
        var wordStarts = Array(repeating: false, count: run.count)
        wordStarts[0] = Self.beginsWord(run[0])
        if tail.count > Self.contextLength {
            // The lookback may start mid-word. Recover at a plausible cluster boundary near
            // the cut, then still require known words between there and the live prefix.
            let lastRecoveryStart = min(max(longestWord, personal.longestWord), run.count - 1)
            if lastRecoveryStart > 0 {
                for start in 1...lastRecoveryStart where Self.isBoundary(start, in: run) {
                    wordStarts[start] = true
                }
            }
        }

        for start in run.indices where wordStarts[start] {
            let prefix = run[start...]
            let personalMatches = personal.terms.filter { $0.count > prefix.count && $0.starts(with: prefix) }
            let preferred = personalMatches.compactMap { units -> Candidate? in
                let word = String(decoding: units, as: UTF16.self)
                guard mayOffer(word) else { return nil }
                return Candidate(word: word, suffix: String(decoding: units.dropFirst(prefix.count), as: UTF16.self))
            }
            if preferred.count >= limit { return Array(preferred.prefix(limit)) }
            var matches = preferred
            var knownPrefix = false
            if prefix.count <= longestWord {
                let first = lowerBound(of: prefix)
                if first < entries.count, entries[first].units.starts(with: prefix) {
                    knownPrefix = true
                    matches += completions(for: prefix, from: first, limit: limit - preferred.count) {
                        !personalMatches.contains($0.units) && mayOffer($0.word)
                    }
                }
            }
            if matches.count < limit, prefix.count >= 2, let expandedWords {
                let range = expandedWords.khmerMatches(prefix)
                // Extra dictionary entries have no measured word frequencies. Fill any
                // spare slots in spelling order, decoding only candidates in this range.
                for index in range where expandedWords.length(index) > prefix.count {
                    let word = expandedWords.word(index)
                    guard !matches.contains(where: { $0.word == word }), mayOffer(word) else { continue }
                    let suffix = String(decoding: word.utf16.dropFirst(prefix.count), as: UTF16.self)
                    matches.append(Candidate(word: word, suffix: suffix))
                    if matches.count == limit { break }
                }
            }
            // A complete word may also start a longer one. Stay at this boundary;
            // if an added compound supplies no chips, still try the older joined reading.
            if knownPrefix || !matches.isEmpty || !personalMatches.isEmpty || personal.words.contains(Array(prefix)) { return matches }
            markWordEnds(from: start, in: run, personal: personal, expanded: expandedWords, into: &wordStarts)
        }
        return []
    }

    /// Offset zero identifies the last code unit before the caret. Positive gain favours the alternative.
    typealias SubstitutionGain = (_ offsetFromEnd: Int, _ typed: UInt16, _ candidate: UInt16) -> Double?

    /// Spelling choices begin at an established Khmer word boundary. A complete reading
    /// as dictionary or personal words keeps the literal text.
    func correction(
        beforeInput: String?, personalWords: [String] = [], learnedSpellings: [String: String] = [:],
        substitutionGain: SubstitutionGain? = nil,
        canCorrect: (String) -> Bool = { _ in true }, mayOffer: (String) -> Bool = { _ in true }
    ) -> Correction? {
        guard let beforeInput else { return nil }
        let tail = beforeInput.utf16.reversed().prefix(Self.contextLength + 1)
        let run = Array(tail.prefix(while: Self.isWordUnit).reversed())
        guard let first = run.first, Self.beginsWord(first), run.last != Self.coeng,
              run.count <= Self.contextLength else { return nil }
        if let separator = tail.dropFirst(run.count).first,
           !Self.isSpellingBoundary(separator) { return nil }

        let personal = PersonalLexicon(personalWords)
        var wordStarts = Array(repeating: false, count: run.count + 1)
        wordStarts[0] = true
        for start in run.indices where wordStarts[start] {
            markWordEnds(from: start, in: run, personal: personal, into: &wordStarts)
        }

        guard !wordStarts[run.count] else { return nil }

        let suffixes = run.indices.filter { wordStarts[$0] }.map { run[$0...] }
        // Let the completion path handle a prefix of a word the person may still be typing.
        guard !suffixes.contains(where: { suffix in
            hasPrefix(suffix) || personal.terms.contains { $0.starts(with: suffix) }
        }) else { return nil }

        // An uncounted dictionary spelling may still have a useful tap-only
        // alternative. Space must keep an entirely recognized reading literal.
        func allowsAutomaticRepair() -> Bool {
            expandedWords == nil || wordSuffix(in: beforeInput[...], personalWords: personalWords) == nil
        }

        // The journal supplies spellings the user has chosen repeatedly. Only a unique
        // repair at an established boundary can replace text automatically.
        if !learnedSpellings.isEmpty {
            let learned = suffixes.compactMap { suffix -> Correction? in
                guard Self.hasCompleteClusters(suffix) else { return nil }
                let typed = String(decoding: suffix, as: UTF16.self)
                guard let replacement = learnedSpellings[typed], !replacement.utf16.elementsEqual(suffix),
                      canCorrect(typed), mayOffer(replacement) else { return nil }
                return Correction(typed: typed, replacement: replacement, automaticallyApplies: allowsAutomaticRepair())
            }
            if !learned.isEmpty { return learned.count == 1 ? learned[0] : nil }
        }
        let eligible = suffixes.filter { spelling in
            spelling.count >= Self.minimumDuplicateMarkLength && spelling.count <= longestWord + 1
        }
        let repeatedMarks = eligible.compactMap(duplicateMarkCorrection)
        // Equivalent readings remove the same scalar. Keep the shortest confirmed replacement.
        if let shortest = repeatedMarks.last, repeatedMarks.allSatisfy({ $0.offset == shortest.offset }) {
            guard canCorrect(shortest.fix.typed), mayOffer(shortest.fix.replacement) else { return nil }
            return Correction(typed: shortest.fix.typed, replacement: shortest.fix.replacement,
                              automaticallyApplies: allowsAutomaticRepair())
        }

        let complete = eligible.filter(Self.hasCompleteClusters)
        for (index, spelling) in complete.enumerated() where spelling.count >= Self.minimumSpellingLength {
            guard let edit = bestSingleEdit(to: spelling, gain: substitutionGain, mayOffer: mayOffer) else { continue }
            let typed = String(decoding: spelling, as: UTF16.self)
            guard canCorrect(typed) else { return nil }
            // Restoring a missing coeng requires a unique repair to a common word
            // and no competing common word at a later boundary.
            let confident = edit.insertsCoeng && edit.unique
                && edit.entry.frequency >= Self.minimumCoengCorrectionFrequency
                && complete.dropFirst(index + 1).allSatisfy {
                    (bestSingleEdit(to: $0)?.entry.frequency ?? 0) < Self.minimumCoengCorrectionFrequency
                }
            let replacement = confident ? edit.entry.word : (edit.spatial?.word ?? edit.entry.word)
            guard mayOffer(replacement) else { return nil }
            return Correction(
                typed: typed, replacement: replacement, automaticallyApplies: confident && allowsAutomaticRepair(),
                rankedByTapPosition: replacement != edit.entry.word,
                dictionaryAlternative: replacement != edit.entry.word && mayOffer(edit.entry.word) ? edit.entry.word : nil
            )
        }
        return nil
    }

    // Unicode 17, chapter 16.4.2, places one dependent vowel slot in the Khmer syllable
    // and pairs each coeng with the following letter.
    private func duplicateMarkCorrection(_ spelling: ArraySlice<UInt16>) -> (offset: Int, fix: Correction)? {
        let repeated = spelling.indices.dropFirst().filter {
            let mark = spelling[$0]
            return mark == spelling[$0 - 1] && (mark == Self.coeng || Self.dependentVowels.contains(mark))
        }
        guard repeated.count == 1, let extra = repeated.first else { return nil }
        var repaired = Array(spelling)
        repaired.remove(at: extra - spelling.startIndex)
        guard Self.hasCompleteClusters(repaired[...]), let match = entry(for: repaired[...]),
              match.frequency > 0 else { return nil }
        return (extra, Correction(typed: String(decoding: spelling, as: UTF16.self), replacement: match.word))
    }

    private func bestSingleEdit(
        to spelling: ArraySlice<UInt16>, gain: SubstitutionGain? = nil, mayOffer: (String) -> Bool = { _ in true }
    ) -> (entry: Entry, insertsCoeng: Bool, unique: Bool, spatial: Entry?)? {
        let original = Array(spelling)
        var best: (entry: Entry, insertsCoeng: Bool)?
        var spatial: (entry: Entry, gain: Double)?
        var unique = true
        func consider(_ units: [UInt16], insertsCoeng: Bool = false, substitution: Int? = nil) {
            guard let match = entry(for: units[...]), match.frequency > 0,
                  Self.hasCompleteClusters(match.units[...]) else { return }
            if let i = substitution, original[i] != Self.coeng, units[i] != Self.coeng,
               let tapGain = gain?(original.count - i - 1, original[i], units[i]),
               tapGain >= Self.minimumSubstitutionGain, mayOffer(match.word),
               spatial.map({ tapGain > $0.gain || (tapGain == $0.gain && ranksAhead(match, $0.entry)) }) ?? true {
                spatial = (match, tapGain)
            }
            if let current = best {
                guard match.units != current.entry.units else { return }
                unique = false
                guard ranksAhead(match, current.entry) else { return }
            }
            best = (match, insertsCoeng)
        }

        for index in original.indices {
            // An edit cannot change the part before it. Stop once that prefix is unknown.
            guard hasPrefix(original.prefix(index)) else { break }
            var removed = original
            removed.remove(at: index)
            consider(removed)

            let unit = original[index]
            if index + 1 < original.count, unit != original[index + 1],
               unit != Self.coeng, original[index + 1] != Self.coeng {
                var transposed = original
                transposed.swapAt(index, index + 1)
                consider(transposed)
            }

            var replaced = original
            var inserted = original
            inserted.insert(unit, at: index)
            for candidate in Self.spellingAlphabet {
                if candidate != unit {
                    replaced[index] = candidate
                    consider(replaced, substitution: index)
                }
                inserted[index] = candidate
                let insertsCoeng = candidate == Self.coeng && index > 0
                    && Self.beginsWord(original[index - 1]) && Self.beginsWord(unit)
                consider(inserted, insertsCoeng: insertsCoeng)
            }
        }
        return best.map { ($0.entry, $0.insertsCoeng, unique, spatial?.entry) }
    }

    private func markWordEnds(from start: Int, in run: [UInt16], personal: PersonalLexicon,
                              expanded: TypingDecoderModel? = nil, into wordStarts: inout [Bool]) {
        if let expanded {
            var range = 0..<expanded.wordCount
            for index in start..<run.count {
                range = expanded.khmerMatches(in: range, depth: index - start, unit: run[index])
                guard !range.isEmpty else { break }
                let end = index + 1
                if end < wordStarts.count, expanded.length(range.lowerBound) == end - start,
                   end == run.count || Self.isBoundary(end, in: run) {
                    wordStarts[end] = true
                }
            }
        }
        let lastEnd = min(start + max(longestWord, personal.longestWord), wordStarts.count - 1)
        guard start < lastEnd else { return }
        for end in (start + 1)...lastEnd where end == run.count || Self.isBoundary(end, in: run) {
            if contains(run[start..<end], personal: personal) { wordStarts[end] = true }
        }
    }

    private func isExpandedWord(_ spelling: ArraySlice<UInt16>) -> Bool {
        guard let expandedWords, let first = expandedWords.khmerMatches(spelling).first else { return false }
        return expandedWords.length(first) == spelling.count
    }

    private func contains(_ spelling: ArraySlice<UInt16>) -> Bool {
        entry(for: spelling) != nil
    }

    private func contains(_ spelling: ArraySlice<UInt16>, personal: PersonalLexicon) -> Bool {
        contains(spelling) || (spelling.count <= personal.longestWord && personal.words.contains(Array(spelling)))
    }

    private func entry(for spelling: ArraySlice<UInt16>) -> Entry? {
        let index = lowerBound(of: spelling)
        guard index < entries.count, entries[index].units.elementsEqual(spelling) else { return nil }
        return entries[index]
    }

    private func hasPrefix(_ spelling: ArraySlice<UInt16>) -> Bool {
        let index = lowerBound(of: spelling)
        return index < entries.count && entries[index].units.starts(with: spelling)
    }

    private func completions(
        for prefix: ArraySlice<UInt16>, from first: Int, limit: Int, mayOffer: (Entry) -> Bool
    ) -> [Candidate] {
        // A single letter can match thousands of words. Keep only the top few, and
        // check the offer policy only when a word could actually enter the strip.
        var best: [Entry] = []
        for entry in entries[first...] {
            guard entry.units.starts(with: prefix) else { break }
            guard entry.units.count > prefix.count else { continue }
            if best.count == limit, let last = best.last, !ranksAhead(entry, last) { continue }
            guard mayOffer(entry) else { continue }
            if best.count == limit { best.removeLast() }
            let index = best.firstIndex { ranksAhead(entry, $0) } ?? best.endIndex
            best.insert(entry, at: index)
        }
        return best.map { entry in
            Candidate(word: entry.word, suffix: String(decoding: entry.units.dropFirst(prefix.count), as: UTF16.self))
        }
    }

    private func ranksAhead(_ left: Entry, _ right: Entry) -> Bool {
        if left.frequency != right.frequency { return left.frequency > right.frequency }
        return left.units.lexicographicallyPrecedes(right.units)
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
    static func isWordUnit(_ unit: UInt16) -> Bool {
        (0x1780...0x17D3).contains(unit) || unit == 0x17DD || unit == 0x200C || unit == 0x200D
    }

    private static func hasCompleteClusters(_ spelling: ArraySlice<UInt16>) -> Bool {
        spelling.last != coeng && !spelling.contains(0x200C) && !spelling.contains(0x200D)
            && spelling.indices.dropLast().allSatisfy { spelling[$0] != coeng || beginsWord(spelling[$0 + 1]) }
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
