@MainActor
extension AutocorrectEngine {
    func khmerCompletions(using index: KhmerAutocomplete, beforeInput: String?) -> [KhmerAutocomplete.Candidate] {
        index.suggestions(beforeInput: beforeInput, personalWords: lexiconTerms) { mayOffer($0) }
    }

    func khmerCorrection(
        using index: KhmerAutocomplete, beforeInput: String?, substitutionGain: KhmerAutocomplete.SubstitutionGain? = nil
    ) -> KhmerAutocomplete.Correction? {
        guard isEnabled else { return nil }
        return index.correction(
            beforeInput: beforeInput, personalWords: lexiconTerms, learnedSpellings: learning.typos,
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
