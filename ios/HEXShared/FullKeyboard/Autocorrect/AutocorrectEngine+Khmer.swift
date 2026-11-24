@MainActor
extension AutocorrectEngine {
    func khmerCompletions(
        using index: KhmerAutocomplete, beforeInput: String?, learnedWords: [String] = []
    ) -> [KhmerAutocomplete.Candidate] {
        index.suggestions(beforeInput: beforeInput, personalWords: lexiconTerms + learnedWords) { mayOffer($0) }
    }

    func khmerCorrection(
        using index: KhmerAutocomplete, beforeInput: String?, learnedWords personalWords: [String] = [],
        substitutionGain: KhmerAutocomplete.SubstitutionGain? = nil
    ) -> KhmerAutocomplete.Correction? {
        guard isEnabled else { return nil }
        return index.correction(
            beforeInput: beforeInput, personalWords: lexiconTerms + personalWords, learnedSpellings: learning.typos,
            substitutionGain: substitutionGain,
            canCorrect: { typed in
                let key = typed.lowercased()
                return !suppressedInSession.contains(key) && !learning.rejected.contains(key) && !learnedWords.contains(key)
                    && !offensiveWords.blocks(typed, allowSwearing: allowsSwearing)
            },
            mayOffer: { mayOffer($0) }
        )
    }
}
