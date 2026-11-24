import UIKit

@MainActor
extension FullKeyboardEngine {
    /// Derive the layer from the caret so it follows Backspace and changes made by the host.
    /// Keep the result for the key plane, which draws every label in one pass.
    func updateKhmerCoengContext() -> Bool {
        let next = layout.language == .khmer && (target.selectedText ?? "").isEmpty
            && typingContext?.utf16.last == 0x17D2
        guard next != isAfterKhmerCoeng else { return false }
        isAfterKhmerCoeng = next
        return true
    }

    func selectionDidChange() {
        commitHangulIfHostMoved()
        guard layout.language == .khmer else { return }
        invalidateMovedKhmerSmartRun()
        invalidateMovedKhmerTaps()
        refreshSuggestions()
    }

    private var allowsKhmerWordChoices: Bool {
        layout.language == .khmer && field.takesWords && !target.hasRestrictedTextContentType
            && target.isSecureTextEntry != true && (target.selectedText ?? "").isEmpty
            && !KhmerAutocomplete.startsWithWordText(target.documentContextAfterInput)
    }

    private var allowsKhmerSuggestions: Bool {
        allowsKhmerWordChoices && target.autocorrectionType != .no
    }

    struct KhmerSpatialTap {
        let unit: UInt16
        let costs: [UInt16: Double]
    }

    struct KhmerTapRun {
        let taps: [KhmerSpatialTap]
        let before: String
        let after: String?
        let document: UUID
        let route: Int
    }

    private func khmerSpatialTap(_ label: String, down: CGPoint?, point: CGPoint) -> KhmerSpatialTap? {
        guard khmerSpatialSuggestions, autocorrect.isEnabled, allowsKhmerSuggestions,
              layerState.layer == .letters, let down, pointOnKeys(down) == point,
              label.utf16.count == 1, let unit = label.utf16.first else { return nil }
        let parameters = TypingDecoder.Parameters()
        let sx = Double(layout.swipePitch) * parameters.sigmaX
        let sy = Double(layout.metrics.keyHeight + layout.metrics.rowGap) * parameters.sigmaY
        var costs: [UInt16: Double] = [:]
        for key in layout.keys where key.character != nil && !key.isNumberRow {
            // Freeze the labels from this tap, before Shift or coeng changes the key plane.
            let glyph = displayLabel(for: key)
            guard glyph.utf16.count == 1, let code = glyph.utf16.first, KhmerismSmartTyping.isBase(code)
                    || KhmerismSmartTyping.isMark(code) else { continue }
            let center = CGPoint(x: key.frame.midX, y: key.frame.midY)
            let cost = TypingDecoder.tapCost(point, centre: center, sigmaX: sx, sigmaY: sy)
            if cost <= parameters.maxTapCost { costs[code] = min(cost, costs[code] ?? .infinity) }
        }
        guard costs[unit] != nil else { return nil }
        return KhmerSpatialTap(unit: unit, costs: costs)
    }

    private func currentKhmerTapRun(before: String?) -> KhmerTapRun? {
        guard let run = khmerTapRun, let before, allowsKhmerSuggestions,
              run.document == target.documentIdentifier, run.route == target.inputRouteRevision,
              run.after == target.documentContextAfterInput,
              before.utf16.elementsEqual(run.before.utf16) else { return nil }
        return run
    }

    func recordKhmerSpatialTap(before: String?, inserted: String, source: String?) {
        guard source == "key", let tap = pendingKhmerTap, inserted.utf16.elementsEqual([tap.unit]),
              let document = target.documentIdentifier, allowsKhmerSuggestions else {
            clearKhmerSpatialTaps()
            return
        }
        let previous = currentKhmerTapRun(before: before)?.taps ?? []
        khmerTapRun = KhmerTapRun(
            taps: Array(previous.suffix(31)) + [tap], before: (before ?? "") + inserted,
            after: target.documentContextAfterInput, document: document, route: target.inputRouteRevision
        )
    }

    func clearKhmerSpatialTaps() { khmerTapRun = nil }

    @discardableResult
    func invalidateMovedKhmerTaps() -> Bool {
        guard khmerTapRun != nil, currentKhmerTapRun(before: typingContext) == nil else { return false }
        clearKhmerSpatialTaps()
        return true
    }

    private func khmerSubstitutionGain(before: String?) -> KhmerAutocomplete.SubstitutionGain? {
        guard let taps = currentKhmerTapRun(before: before)?.taps else { return nil }
        return { offset, typed, candidate in
            guard taps.indices.contains(offset) else { return nil }
            let tap = taps[taps.count - offset - 1]
            // Central taps carry no mistap evidence. Near a key edge, a neighbour
            // can be plausible even when the tap fell just inside the literal key.
            guard tap.unit == typed, let literal = tap.costs[typed], literal >= 0.65,
                  let alternate = tap.costs[candidate] else { return nil }
            return literal - alternate + 2.5
        }
    }

    /// Load and index the shared list once, off the typing path.
    func loadKhmerAutocompleteIfNeeded() {
        guard khmerAutocompleteLoad == nil else { return }
        khmerAutocompleteLoad = Task { [weak self] in
            let index = await Task.detached(priority: .utility) { KhmerAutocomplete.bundled }.value
            self?.khmerAutocomplete = index
            self?.refreshSuggestions()
        }
    }

    struct KhmerPredictionCaret: Equatable {
        var before: String?
        let after: String?
        let document: UUID?
        let route: Int
    }

    func khmerPredictionCaret(before: String?) -> KhmerPredictionCaret {
        KhmerPredictionCaret(before: before, after: target.documentContextAfterInput,
                            document: target.documentIdentifier, route: target.inputRouteRevision)
    }

    func rememberKhmerPickedWord(_ word: String, before: String) {
        khmerPickedWord = allowsKhmerSuggestions ? (word, khmerPredictionCaret(before: before)) : nil
    }

    struct KhmerTypedRun {
        let text: String
        let previous: String?
        var caret: KhmerPredictionCaret
    }

    private var khmerLearning: TypingJournal? {
        guard khmerPersonalSuggestions, allowsKhmerSuggestions, target.documentIdentifier != nil else { return nil }
        return learning
    }

    private func khmerPreviousWord(at caret: KhmerPredictionCaret, learnedWords: [String]) -> String? {
        if khmerPrefixAfterPick(at: caret) != nil { return khmerPickedWord?.word }
        guard let before = caret.before, !khmerStartsSentence(before: before) else { return nil }
        return khmerAutocomplete?.separatedContext(in: before, personalWords: autocorrect.ownWords + learnedWords)?.word
    }

    func alignKhmerTypedRun(before: String?) {
        guard var run = khmerTypedRun else { return }
        let caret = khmerPredictionCaret(before: before)
        if run.caret == caret { return }
        defer { khmerTypedRun = run.caret == caret ? run : nil }
        // A capped proxy may drop units on the left. Keep the run only if the whole
        // visible window matches the expected edit and still holds every typed unit.
        guard let edit = expectedTypingContext, let before, let old = run.caret.before,
              let reported = edit.reported, reported.utf16.count == before.utf16.count,
              before.utf16.count >= run.text.utf16.count, old.utf16.count > before.utf16.count,
              old.utf16.elementsEqual(edit.expected.utf16),
              before.utf16.elementsEqual(old.utf16.suffix(before.utf16.count)) else { return }
        run.caret.before = before
    }

    func observeKhmerTyping(_ text: String, source: String?, before: String?) {
        alignKhmerTypedRun(before: before)
        let run = khmerTypedRun
        khmerTypedRun = nil
        guard let journal = khmerLearning, let index = khmerAutocomplete else { return }
        let caret = khmerPredictionCaret(before: before)

        if text == "\n" || text == " " || text == "\u{200B}" || text.isEmpty
            || (text.count == 1 && text.first.map({ Self.wordEnders.contains($0) || Self.khmerClosingMarks.contains($0) }) == true) {
            guard let run, text == "\n" || source == "key" || source == "slide" || source == "khmerism_hold" else { return }
            let words = index.wordsForLearning(
                in: run.text, vocabulary: autocorrect.lexiconTerms + journal.khmerSuggestions.preferredWords(),
                allowsNewWord: true
            )
            guard !words.isEmpty, words.allSatisfy({ autocorrect.mayOffer($0) }) else { return }
            journal.recordKhmerWords(words, after: run.previous)
            return
        }

        guard source == "key" || source == "slide" || source == "khmerism_hold" || source == "accent",
              text.utf16.allSatisfy(KhmerAutocomplete.isWordUnit) else { return }
        let atBoundary = before?.utf16.last.map { !KhmerAutocomplete.isWordUnit($0) } ?? !target.hasText
        guard run != nil || atBoundary || khmerPrefixAfterPick(at: caret)?.isEmpty == true else { return }
        let typed = (run?.text ?? "") + text
        guard typed.utf16.count <= KhmerAutocomplete.learningRunLimit else { return }
        let previous = if let run { run.previous } else {
            khmerPreviousWord(at: caret, learnedWords: journal.khmerSuggestions.preferredWords())
        }
        khmerTypedRun = KhmerTypedRun(
            text: typed, previous: previous,
            caret: khmerPredictionCaret(before: (before ?? "") + text)
        )
    }

    /// An explicit choice establishes a word boundary even though Khmer inserts no space.
    func khmerPrefixAfterPick(at caret: KhmerPredictionCaret) -> String? {
        guard let pick = khmerPickedWord, pick.caret.document == caret.document, pick.caret.route == caret.route,
              pick.caret.after == caret.after, let before = caret.before, let boundary = pick.caret.before else { return nil }
        let visibleBoundaryLength: Int
        if before.utf16.starts(with: boundary.utf16) {
            visibleBoundaryLength = boundary.utf16.count
        } else {
            // A capped proxy drops text on the left after each insert. Rebase only when its
            // entire visible window matches our own edit and still contains the chosen word.
            let length = before.utf16.count
            guard let edit = expectedTypingContext, edit.document == caret.document, edit.after == caret.after,
                  let reported = edit.reported, length == reported.utf16.count || before.count == reported.count,
                  edit.expected.utf16.starts(with: boundary.utf16),
                  edit.expected.utf16.count > length, before.utf16.elementsEqual(edit.expected.utf16.suffix(length)) else { return nil }
            visibleBoundaryLength = boundary.utf16.count - (edit.expected.utf16.count - length)
            guard visibleBoundaryLength >= pick.word.utf16.count else { return nil }
            khmerPickedWord?.caret.before = String(decoding: before.utf16.prefix(visibleBoundaryLength), as: UTF16.self)
        }
        let prefix = before.utf16.dropFirst(visibleBoundaryLength)
        guard prefix.allSatisfy(KhmerAutocomplete.isWordUnit) else { return nil }
        return String(decoding: prefix, as: UTF16.self)
    }

    private static let khmerStarters = ["ខ្ញុំ", "សូម", "តើ"]
    private static let khmerCommonWords = ["បាន", "មាន", "នៅ", "ទៅ"]

    private func khmerFollowingWords(
        _ previous: String, prefix: String = "", usage: KhmerSuggestionLearning
    ) -> [String] {
        func allowed(_ word: String) -> Bool {
            word != previous && autocorrect.mayOffer(word, after: previous)
        }
        let compact = TypingDecoderModel.bundled(KeyboardLanguage.khmer.rawValue)
        // Keep the established first-key ranking. With a known boundary or a
        // longer prefix, the wider set of continuations becomes more useful.
        let model = prefix.utf16.count == 1 ? compact : (khmerAutocomplete?.expandedWords ?? compact)
        var words = Array(usage.preferredWords(after: previous, prefix: prefix).filter(allowed).prefix(3))
        if words.count < 3 {
            let predicted = model?.nextWords(after: previous, khmerPrefix: prefix) {
                allowed($0) && !words.contains($0)
            } ?? []
            words.append(contentsOf: predicted.prefix(3 - words.count))
        }
        // While typing a prefix, the ordinary frequency-ranked completions fill any spare slots.
        guard prefix.isEmpty else { return words }
        for word in Self.khmerCommonWords where words.count < 3 && !words.contains(word) && allowed(word) {
            words.append(word)
        }
        return words
    }

    private func khmerStartsSentence(before: String?) -> Bool {
        guard let before, !before.isEmpty else { return !target.hasText }
        var trimmed = before[...]
        while trimmed.last == " " || trimmed.last == "\u{200B}" { trimmed = trimmed.dropLast() }
        guard let last = trimmed.last else { return true }
        return last.isNewline || ["។", "៕", ".", "!", "?"].contains(last)
    }

    private func khmerPredictions(_ words: [String]) -> [KeyboardSuggestion] {
        words.map { KeyboardSuggestion(displayText: $0, replacement: $0, kind: .khmerPrediction) }
    }

    private func khmerEnglishMatch(using index: KhmerAutocomplete, before: String?) -> KhmerAutocomplete.EnglishMatch? {
        guard khmerEnglishSuggestions, target.documentIdentifier != nil, let before,
              let match = index.englishMatch(in: before, personalWords: autocorrect.ownWords) else { return nil }
        return match
    }

    func khmerSuggestionChoices(live: Bool = false) -> [KeyboardSuggestion] {
        guard allowsKhmerWordChoices else { return [] }
        let before = live ? textBefore : typingContext
        let caret = khmerPredictionCaret(before: before)
        let prefix = khmerPrefixAfterPick(at: caret)
        if prefix == nil && !live { khmerPickedWord = nil }
        let input = prefix ?? before
        let match = khmerAutocomplete.flatMap { khmerEnglishMatch(using: $0, before: input) }
        // Search fields can disable corrections and still accept explicit transliteration picks.
        let offersDictionaryChoices = target.autocorrectionType != .no
        var ordinary = offersDictionaryChoices
            ? khmerDictionaryChoices(before: before, prefix: prefix, hasEnglishMatch: match != nil)
            : []
        guard let match else { return ordinary }
        let english = KeyboardSuggestion(
            displayText: match.english, replacement: match.english, kind: .khmerEnglish(typed: match.typed)
        )
        if match.typed != match.khmer {
            let suffix = String(decoding: match.khmer.utf16.dropFirst(match.typed.utf16.count), as: UTF16.self)
            let completion = KeyboardSuggestion(displayText: match.khmer, replacement: suffix, kind: .khmerCompletion)
            // Keep the highest-ranked distinct Khmer choice alongside the two matched spellings.
            let first = ordinary.first { $0.displayText != match.khmer && $0.kind != .khmerKeepLiteral }
            guard let first else { return [completion, english] }
            return ordinary.first?.displayText == match.khmer ? [completion, first, english] : [first, completion, english]
        }
        if offersDictionaryChoices, !ordinary.contains(where: { $0.kind == .khmerKeepLiteral }),
           khmerAutocomplete?.wordSuffix(in: match.typed[...], personalWords: autocorrect.ownWords) == match.typed {
            ordinary.insert(
                KeyboardSuggestion(displayText: match.typed, replacement: match.typed, kind: .khmerKeepLiteral), at: 0
            )
        }
        return Array(ordinary.prefix(2)) + [english]
    }

    private func khmerDictionaryChoices(before: String?, prefix: String?, hasEnglishMatch: Bool) -> [KeyboardSuggestion] {
        let usage = khmerLearning?.khmerSuggestions ?? KhmerSuggestionLearning()
        let learnedWords = usage.preferredWords()
        let context: (word: String, prefix: String)?
        if let prefix, let pick = khmerPickedWord {
            context = (pick.word, prefix)
        } else if khmerStartsSentence(before: before) {
            return khmerPredictions(Self.khmerStarters.filter { autocorrect.mayOffer($0) })
        } else {
            context = before.flatMap {
                khmerAutocomplete?.separatedContext(in: $0, personalWords: autocorrect.ownWords + learnedWords)
            }
        }
        if let context, context.prefix.isEmpty {
            return khmerPredictions(khmerFollowingWords(context.word, usage: usage))
        }
        guard let index = khmerAutocomplete else { return [] }
        let input = prefix ?? before
        if let correction = autocorrect.khmerCorrection(
            using: index, beforeInput: input, learnedWords: learnedWords, substitutionGain: khmerSubstitutionGain(before: before)
        ), target.documentIdentifier != nil || khmerReplacementTail(
            from: correction.typed, to: correction.replacement
        ).removed.isEmpty {
            var choices = [
                KeyboardSuggestion(displayText: "“\(correction.typed)”", replacement: correction.typed, kind: .khmerKeepLiteral),
                KeyboardSuggestion(
                    displayText: correction.replacement, replacement: correction.replacement,
                    kind: .khmerCorrection(autoReplace: correction.automaticallyApplies && !hasEnglishMatch)
                ),
            ]
            if let word = correction.dictionaryAlternative {
                choices.append(KeyboardSuggestion(displayText: word, replacement: word, kind: .khmerCorrection(autoReplace: false)))
            } else if correction.typed.utf16.count >= 2, index.expandedWords != nil,
                      let completion = autocorrect.khmerCompletions(using: index, beforeInput: correction.typed).first(where: {
                          $0.word != correction.replacement && $0.word.utf16.starts(with: correction.typed.utf16)
                      }) {
                choices.append(KeyboardSuggestion(displayText: completion.word, replacement: completion.suffix, kind: .khmerCompletion))
            }
            return choices
        }
        var completions = autocorrect.khmerCompletions(
            using: index, beforeInput: input, learnedWords: learnedWords
        ).map {
            KeyboardSuggestion(displayText: $0.word, replacement: $0.suffix, kind: .khmerCompletion)
        }
        if let context {
            let prefix = context.prefix
            let preferred = khmerFollowingWords(context.word, prefix: prefix, usage: usage)
            let personal = completions.prefix { autocorrect.lexiconTerms.contains($0.displayText) }
            let contextual = preferred.filter { word in !personal.contains { $0.displayText == word } }.map { word in
                let suffix = String(decoding: word.utf16.dropFirst(prefix.utf16.count), as: UTF16.self)
                return KeyboardSuggestion(displayText: word, replacement: suffix, kind: .khmerCompletion)
            }
            let remaining = completions.dropFirst(personal.count).filter { !preferred.contains($0.displayText) }
            completions = Array((Array(personal) + contextual + remaining).prefix(3))
        }
        return completions
    }

    /// Khmer chips describe a suffix in joined text. Recheck it against the live caret before editing.
    func acceptKhmerSuggestion(_ suggestion: KeyboardSuggestion) -> Bool {
        switch suggestion.kind {
        case .khmerCompletion, .khmerPrediction, .khmerKeepLiteral, .khmerCorrection, .khmerEnglish:
            let caret = khmerPredictionCaret(before: textBefore)
            guard khmerStripCaret == caret, suggestions.contains(suggestion), khmerSuggestionChoices(live: true).contains(suggestion) else {
                refreshSuggestions()
                return true
            }
            if suggestion.kind == .khmerCompletion || suggestion.kind == .khmerPrediction {
                if let journal = khmerLearning, let index = khmerAutocomplete {
                    let learnedWords = journal.khmerSuggestions.preferredWords()
                    let words = index.wordsForLearning(in: suggestion.displayText, vocabulary: autocorrect.lexiconTerms + learnedWords)
                    if words.count == 1, autocorrect.mayOffer(words[0]) {
                        journal.recordKhmerWords(words, after: khmerPreviousWord(at: caret, learnedWords: learnedWords))
                    }
                }
                rememberKhmerPickedWord(suggestion.displayText, before: (caret.before ?? "") + suggestion.replacement)
                insert(suggestion.replacement, source: suggestion.kind == .khmerPrediction ? "khmer_prediction" : "khmer_completion")
            } else if suggestion.kind == .khmerKeepLiteral {
                autocorrect.suppressAndKeep(suggestion.replacement)
                refreshSuggestions()
            } else if case .khmerEnglish(let typed) = suggestion.kind {
                if let before = caret.before { replaceKhmerWithEnglish(typed: typed, before: before, suggestion: suggestion) }
            } else {
                applyKhmerCorrection(ending: "", picked: suggestion.replacement)
            }
            return true
        case .swiped:
            guard let choices = pendingKhmerSwipeChoices else { return false }
            guard suggestions.contains(suggestion), choices.words.contains(suggestion.replacement) else { return true }
            let canInsert = khmerSwipeChoicesAreCurrent
            dismissKhmerSwipeChoices()
            if canInsert {
                commitSwipe([suggestion.replacement] + choices.words.filter { $0 != suggestion.replacement })
            } else {
                refreshSuggestions()
            }
            return true
        default:
            return false
        }
    }

    struct KhmerSmartRun {
        let syllable: String
        let context: ExpectedTypingContext
        let tapTime: TimeInterval?
    }

    private var allowsKhmerSmartTyping: Bool {
        autocorrect.isEnabled && allowsKhmerSuggestions
    }

    private var currentKhmerSmartRun: KhmerSmartRun? {
        guard let run = khmerSmartRun, allowsKhmerSmartTyping,
              target.documentIdentifier == run.context.document,
              target.documentContextAfterInput == run.context.after, let before = typingContext else { return nil }
        if before.utf16.elementsEqual(run.context.expected.utf16) { return run }
        // A capped UITextDocumentProxy context may drop text at the left after an insert.
        let length = before.utf16.count
        guard length == run.context.reported?.utf16.count, length >= run.syllable.utf16.count,
              before.utf16.elementsEqual(run.context.expected.utf16.suffix(length)) else { return nil }
        return run
    }

    func invalidateMovedKhmerSmartRun() {
        guard khmerSmartRun != nil, currentKhmerSmartRun == nil else { return }
        clearKhmerSmartRun()
        onChange?()
    }

    func clearKhmerSmartRun() {
        khmerSmartRun = nil
    }

    var adaptiveKhmerSign: String? {
        guard let syllable = currentKhmerSmartRun?.syllable else { return nil }
        return KhmerismSmartTyping.adaptiveSigns[syllable]
    }

    func commitKhmerCharacter(_ key: KeyboardKey, at point: CGPoint, down: CGPoint?) {
        // The standard layout puts some Smart Mode inputs, such as ញ and ំ, on Shift.
        let directTap = !isUppercase || layout.letters == .khmer
        let label = displayLabel(for: key)
        pendingKhmerTap = khmerSpatialTap(label, down: down, point: point)
        defer { pendingKhmerTap = nil }
        insertKhmerKeyText(label, source: "key", at: point, directTap: directTap)
    }

    func insertKhmerKeyText(
        _ text: String, source: String, at point: CGPoint? = nil, directTap: Bool = false
    ) {
        if khmerDeleteRecovery != nil {
            khmerDeleteRecovery?.input += text
            return
        }
        spaceBeforeNextWord(text)
        if layerState.layer == .letters {
            shift.didType()
            logState("typed")
        }
        if typeEmojiShortcode(text) { return }
        if typeKhmerSmartKey(text, source: source, at: point, directTap: directTap) { return }
        if dropsSuggestionSpace(before: text) || !correctWord(endingWith: text) {
            insert(text, source: source, at: point)
        }
    }

    private func typeKhmerSmartKey(_ text: String, source: String, at point: CGPoint?, directTap: Bool) -> Bool {
        guard allowsKhmerSmartTyping, layerState.layer == .letters,
              let unit = text.utf16.first, text.utf16.count == 1 else { return false }
        let run = currentKhmerSmartRun
        let before = typingContext
        let afterCoeng = before?.utf16.last == KhmerismSmartTyping.coeng
        let tapTime = directTap ? clock() : nil

        if KhmerismSmartTyping.isBase(unit), !afterCoeng {
            insert(text, source: source, at: point, khmerSyllable: text, khmerTapTime: tapTime)
            return true
        }
        guard KhmerismSmartTyping.isMark(unit) || (afterCoeng && KhmerismSmartTyping.isBase(unit)) else { return false }
        guard let run, run.syllable.utf16.count < 16 else {
            if directTap, KhmerismSmartTyping.startsVowelPair(text),
               before?.utf16.last.map({ !KhmerismSmartTyping.isBase($0) && !KhmerismSmartTyping.isMark($0) }) ?? true {
                insert(text, source: source, at: point, khmerSyllable: text, khmerTapTime: tapTime)
                return true
            }
            return false
        }

        let repeatsTap = tapTime.flatMap { now in run.tapTime.map { now <= $0 + KhmerismSmartTyping.doubleTapWindow } } == true
            && run.syllable.utf16.last == unit
        if let replacement = KhmerismSmartTyping.replacement(
            adding: text, to: run.syllable, afterTap: directTap && run.tapTime != nil, repeatsTap: repeatsTap
        ) {
            // A vowel shortcut keeps the first vowel and appends its second sign.
            if replacement.utf16.starts(with: run.syllable.utf16) {
                let added = String(decoding: replacement.utf16.dropFirst(run.syllable.utf16.count), as: UTF16.self)
                if !added.isEmpty { insert(added, source: source, at: point, khmerSyllable: replacement) }
                return true
            }
            // The proxy must confirm the exact suffix before a replacement can delete it.
            if let live = textBefore, let before, live.utf16.elementsEqual(before.utf16) {
                let change = khmerReplacementTail(from: run.syllable, to: replacement)
                if removeKhmerSuffix(change.removed, from: live) != nil {
                    typingLog?.edit("delete", [
                        TypingLogField("deleted", .string(change.removed)),
                        TypingLogField("src", .string("khmerism_smart")),
                    ])
                    forgetTypingContext()
                    insert(change.inserted, source: source, at: point, khmerSyllable: replacement)
                    return true
                }
                // The host may have stopped responding after a delete. Start a fresh run.
                forgetTypingContext()
                return false
            }
        }
        insert(text, source: source, at: point, khmerSyllable: run.syllable + text, khmerTapTime: tapTime)
        return true
    }

    static let khmerClosingMarks: Set<Character> = ["។", "៕", "៖"]

    @discardableResult
    func applyKhmerCorrection(ending: String, picked: String? = nil) -> Bool {
        guard allowsKhmerSuggestions, let before = textBefore, before == typingContext,
              let index = khmerAutocomplete else { return false }
        let input = khmerPrefixAfterPick(at: khmerPredictionCaret(before: before)) ?? before
        guard picked != nil || khmerEnglishMatch(using: index, before: input) == nil,
              let suggested = autocorrect.khmerCorrection(
                using: index, beforeInput: input,
                learnedWords: khmerLearning?.khmerSuggestions.preferredWords() ?? [],
                substitutionGain: picked == nil ? nil : khmerSubstitutionGain(before: before)
              ) else {
            return false
        }
        let correction: KhmerAutocomplete.Correction
        if let picked {
            guard let choice = suggested.selecting(picked) else { return false }
            correction = choice
        } else {
            guard suggested.automaticallyApplies else { return false }
            correction = suggested
        }

        let change = khmerReplacementTail(from: correction.typed, to: correction.replacement)
        guard let prefix = removeKhmerSuffix(change.removed, from: before) else { return false }
        let inserted = change.inserted + ending
        if ending.isEmpty {
            rememberKhmerPickedWord(correction.replacement, before: prefix + change.inserted)
        }
        rememberTypingContext(before: prefix, inserted: inserted)
        if !inserted.isEmpty {
            target.insertText(change.inserted + smartened(ending, after: correction.replacement.last))
        }
        typingLog?.edit("autocorrect", [
            TypingLogField("from", .string(correction.typed)),
            TypingLogField("to", .string(correction.replacement)),
            TypingLogField("deleted", .string(change.removed)),
            TypingLogField("inserted", .string(inserted)),
            TypingLogField("picked", .bool(picked != nil)),
        ])
        autocorrect.recordAppliedCorrection(
            original: correction.typed, corrected: correction.replacement, anchor: prefix + change.inserted,
            changes: [.init(from: correction.typed, to: correction.replacement, language: .khmer)],
            document: target.documentIdentifier
        )
        // A suggestion offered by the experiment must not become an automatic journal repair.
        if correction.rankedByTapPosition {
            learning?.didFinish(word: nil)
        } else {
            learning?.record(
                picked != nil ? .picked : .autocorrected,
                typed: correction.typed, final: correction.replacement, language: KeyboardLanguage.khmer.rawValue
            )
        }
        tokenTaps.removeAll()
        finishedWord = nil
        swipedWord = nil
        lastSpaceAt = nil
        didEdit()
        return true
    }

    /// Keep the exact shared prefix so the proxy only has to delete characters that change.
    func khmerReplacementTail(from original: String, to replacement: String) -> (removed: String, inserted: String) {
        let shared = zip(original, replacement).prefix {
            String($0.0).utf16.elementsEqual(String($0.1).utf16)
        }.count
        return (String(original.dropFirst(shared)), String(replacement.dropFirst(shared)))
    }

    enum KhmerSuffixDeletion {
        case rejected
        case interrupted
        case removed(prefix: String)
    }

    struct KhmerDeleteRecovery {
        let caret: KhmerDeleteCaret
        let task: Task<Void, Never>
        var input = ""
        var probingRightContext = false
    }

    struct KhmerDeleteCaret {
        let document: UUID
        let routeRevision: Int
        let after: String?
    }

    func removeKhmerSuffix(_ suffix: String, from before: String) -> String? {
        guard case .removed(let prefix) = deleteKhmerSuffix(suffix, from: before) else { return nil }
        return prefix
    }

    /// UIKit can delete one Khmer scalar where Swift sees a whole character. Stop at the
    /// exact word boundary, checking each step against the original text before the caret.
    func deleteKhmerSuffix(_ suffix: String, from before: String) -> KhmerSuffixDeletion {
        guard khmerDeleteRecovery == nil, let rawBefore = target.documentContextBeforeInput,
              SmartPunctuation.plain(rawBefore).utf16.elementsEqual(before.utf16),
              before.utf16.suffix(suffix.utf16.count).elementsEqual(suffix.utf16),
              (target.selectedText ?? "").isEmpty else { return .rejected }
        guard !suffix.isEmpty else { return .removed(prefix: before) }
        // A host can apply a delete before reporting it. Without a field ID, a delayed
        // report cannot safely authorize a rollback, so leave the original text intact.
        guard let document = target.documentIdentifier else { return .rejected }
        let original = Array(rawBefore.utf16)
        let boundary = original.count - suffix.utf16.count
        let caret = KhmerDeleteCaret(
            document: document,
            routeRevision: target.inputRouteRevision,
            after: target.documentContextAfterInput
        )
        // The English replacement verifies an empty prefix separately when text follows it.
        guard boundary != 0 || caret.after?.isEmpty != false else { return .rejected }
        var end = original.count
        var previous = rawBefore
        while end > boundary {
            target.deleteBackward()
            var confirmed: (text: String, end: Int)?
            for _ in 0..<3 {
                guard sameKhmerDeleteCaret(caret) else {
                    // The original key's fallback runs before the next turn of the main actor.
                    // Do not let it send text to the field that took over during deletion.
                    khmerDeleteRecovery = KhmerDeleteRecovery(caret: caret, task: Task { [weak self] in
                        self?.finishKhmerDeleteRecovery(at: caret)
                    })
                    return .interrupted
                }
                confirmed = observedKhmerDelete(before: previous, end: end, live: target.documentContextBeforeInput)
                if confirmed != nil { break }
            }
            guard let confirmed else {
                recoverKhmerDelete(in: original, before: previous, end: end, at: caret)
                return .interrupted
            }
            end = confirmed.end
            if end < boundary {
                target.insertText(String(decoding: original.dropFirst(end), as: UTF16.self))
                return .interrupted
            }
            previous = confirmed.text
        }
        return .removed(prefix: SmartPunctuation.plain(previous))
    }

    /// A new finger in a different field starts a new edit. Drop only the old field's queued input.
    func cancelKhmerRecoveryIfCaretChanged() {
        guard let recovery = khmerDeleteRecovery, !canAwaitKhmerDelete(recovery) else { return }
        recovery.task.cancel()
        khmerDeleteRecovery = nil
        forgetTypingContext()
        cancelAllTouches()
    }

    /// Backspace can undo input waiting behind the outstanding proxy delete.
    func consumeDeleteDuringKhmerRecovery() -> Bool {
        guard let recovery = khmerDeleteRecovery else { return false }
        if !recovery.input.isEmpty { khmerDeleteRecovery?.input.removeLast() }
        return true
    }

    private func sameKhmerDeleteCaret(_ caret: KhmerDeleteCaret) -> Bool {
        sameKhmerDeleteDocument(caret) && target.documentContextAfterInput == caret.after
    }

    private func sameKhmerDeleteDocument(_ caret: KhmerDeleteCaret) -> Bool {
        target.documentIdentifier == caret.document && target.inputRouteRevision == caret.routeRevision
            && (target.selectedText ?? "").isEmpty
    }

    private func canAwaitKhmerDelete(_ recovery: KhmerDeleteRecovery) -> Bool {
        let caret = recovery.caret
        guard sameKhmerDeleteDocument(caret) else { return false }
        if target.documentContextAfterInput == caret.after { return true }
        guard recovery.probingRightContext, let right = caret.after, let next = right.first else { return false }
        guard let after = target.documentContextAfterInput else { return true } // host is still reporting the move
        return [1, String(next).utf16.count].contains { count in
            after.utf16.starts(with: String(decoding: right.utf16.dropFirst(count), as: UTF16.self).utf16)
        }
    }

    private func replaceKhmerWithEnglish(typed: String, before: String, suggestion: KeyboardSuggestion) {
        let shown = suggestions
        let applyPick = { [weak self] in
            guard let self else { return }
            self.typingLog?.edit("suggestion", [
                TypingLogField("slot", shown.firstIndex(of: suggestion).map { .int($0) } ?? .null),
                TypingLogField("text", .string(suggestion.displayText)),
                TypingLogField("deleted", .string(typed)),
                TypingLogField("inserted", .string(suggestion.replacement)),
                TypingLogField("candidates", TypingLogger.candidates(shown)),
            ])
            self.forgetTextAroundKeys()
            self.insert(suggestion.replacement, source: nil)
        }
        guard before.utf16.elementsEqual(typed.utf16), let after = target.documentContextAfterInput, !after.isEmpty else {
            if removeKhmerSuffix(typed, from: before) != nil { applyPick() }
            return
        }
        guard let document = target.documentIdentifier else { return }
        let caret = KhmerDeleteCaret(document: document, routeRevision: target.inputRouteRevision, after: after)
        khmerDeleteRecovery = KhmerDeleteRecovery(caret: caret, task: Task { [weak self] in
            await self?.replaceKhmerPrefixBeforeFollowingText(before, at: caret, applyPick: applyPick)
        })
    }

    /// A proxy can report nil before the cursor at the start of a nonempty field. Verify
    /// that position across the following character, keeping new keys queued through both moves.
    private func replaceKhmerPrefixBeforeFollowingText(_ before: String, at caret: KhmerDeleteCaret,
                                                       applyPick: @escaping () -> Void) async {
        guard !Task.isCancelled, sameKhmerDeleteCaret(caret),
              target.documentContextBeforeInput?.utf16.elementsEqual(before.utf16) == true else {
            finishKhmerDeleteRecovery(at: caret)
            return
        }
        let verified = await probeKhmerPrefix(at: caret, possible: [before])
        let atOriginal = sameKhmerDeleteCaret(caret) && target.documentContextBeforeInput?.utf16.elementsEqual(before.utf16) == true
        guard verified != nil, atOriginal else {
            // An ignored preflight hasn't erased anything. Replay only if both sides
            // still identify the original caret after waiting for the move's report.
            return finishKhmerDeleteRecovery(restoring: atOriginal ? "" : nil, at: caret)
        }
        var previous = before
        var end = before.utf16.count
        while end > 0 {
            guard !Task.isCancelled, sameKhmerDeleteCaret(caret) else { return finishKhmerDeleteRecovery(at: caret) }
            target.deleteBackward()
            var probedStart = false
            let confirmed = await waitForKhmerReport(at: caret) { () -> (text: String, end: Int)? in
                guard self.sameKhmerDeleteCaret(caret) else { return nil }
                var live = self.target.documentContextBeforeInput
                if live == nil, previous.count == 1, !probedStart {
                    probedStart = true
                    live = await self.probeKhmerPrefix(at: caret, possible: [previous, String(previous.unicodeScalars.dropLast()), ""])
                }
                guard self.sameKhmerDeleteCaret(caret) else { return nil }
                return self.observedKhmerDelete(before: previous, end: end, live: live)
            }
            guard let confirmed else {
                let unchanged = target.documentContextBeforeInput?.utf16.elementsEqual(previous.utf16) == true
                let restored = unchanged ? String(decoding: before.utf16.dropFirst(end), as: UTF16.self) : nil
                return finishKhmerDeleteRecovery(restoring: restored, at: caret)
            }
            previous = confirmed.text
            end = confirmed.end
        }
        finishKhmerDeleteRecovery(restoring: "", at: caret, applyPick: applyPick)
    }

    /// Issue each move once. A later host report must confirm it before the next
    /// move or edit. A bounded right context may reveal more text when moving forward.
    private func probeKhmerPrefix(at caret: KhmerDeleteCaret, possible: [String]) async -> String? {
        guard !Task.isCancelled, sameKhmerDeleteCaret(caret), let right = caret.after, let next = right.first else { return nil }
        khmerDeleteRecovery?.probingRightContext = true
        defer { if !Task.isCancelled { khmerDeleteRecovery?.probingRightContext = false } }
        target.adjustTextPosition(byCharacterOffset: 1)
        let width = String(next).utf16.count
        guard let prefix = await waitForKhmerReport(at: caret, read: { () -> String? in
            guard let left = self.target.documentContextBeforeInput else { return nil }
            let after = self.target.documentContextAfterInput ?? ""
            for consumed in width == 1 ? [1] : [width, 1] {
                let crossed = String(decoding: right.utf16.prefix(consumed), as: UTF16.self)
                let remaining = String(decoding: right.utf16.dropFirst(consumed), as: UTF16.self)
                guard left.utf16.suffix(consumed).elementsEqual(crossed.utf16),
                      after.utf16.starts(with: remaining.utf16) else { continue }
                let prefix = String(decoding: left.utf16.dropLast(consumed), as: UTF16.self)
                // The crossed character alone can fill the host's left window.
                // Its movement still needs to be reversed before judging the prefix.
                if prefix.isEmpty || possible.contains(where: { $0.utf16.suffix(prefix.utf16.count).elementsEqual(prefix.utf16) }) {
                    return prefix
                }
            }
            return nil
        }) else { return nil }
        guard !Task.isCancelled, sameKhmerDeleteDocument(caret) else { return nil }
        target.adjustTextPosition(byCharacterOffset: -1)
        let returned: String? = await waitForKhmerReport(at: caret) {
            guard self.sameKhmerDeleteCaret(caret) else { return nil }
            let live = self.target.documentContextBeforeInput ?? ""
            let matches = prefix.isEmpty ? possible.contains(live) : live.utf16.suffix(prefix.utf16.count).elementsEqual(prefix.utf16)
            return matches ? live : nil
        }
        guard !prefix.isEmpty || possible.contains("") else { return nil }
        return returned
    }

    private func waitForKhmerReport<T>(at caret: KhmerDeleteCaret, read: @MainActor () async -> T?) async -> T? {
        for attempt in 0..<5 {
            if attempt > 0 { try? await Task.sleep(for: .milliseconds(12 << (attempt - 1))) }
            guard !Task.isCancelled, sameKhmerDeleteDocument(caret) else { return nil }
            for _ in 0..<3 {
                if let value = await read() { return value }
            }
        }
        return nil
    }

    private func observedKhmerDelete(before: String, end: Int, live: String?) -> (text: String, end: Int)? {
        guard let live else {
            return target.hasText ? nil : ("", 0)
        }
        guard !live.utf16.elementsEqual(before.utf16) else { return nil }
        let length = live.utf16.count
        // A bounded window can reveal text preceding the original suffix. Keep that
        // text as an anchor, including on the last delete when none of the suffix remains.
        let anchorLength = before.utf16.count - end
        if length >= anchorLength, length < before.utf16.count,
           live.utf16.elementsEqual(before.utf16.prefix(length)) { return (live, length - anchorLength) }
        guard length == before.utf16.count || live.count == before.count else { return nil }
        let matches = (0..<end).filter { remaining in
            let retained = anchorLength + remaining
            return retained > 0 && length >= retained
                && live.utf16.suffix(retained).elementsEqual(before.utf16.prefix(retained))
        }
        guard matches.count == 1, let end = matches.first else { return nil }
        return (live, end)
    }

    /// The proxy may need a run loop to publish a delete. Stop the edit and recover the
    /// original spelling before sending any literal key text waiting behind it.
    private func recoverKhmerDelete(in original: [UInt16], before: String, end: Int, at caret: KhmerDeleteCaret) {
        khmerDeleteRecovery = KhmerDeleteRecovery(caret: caret, task: Task { [weak self] in
            for attempt in 0..<5 {
                if attempt > 0 { try? await Task.sleep(for: .milliseconds(12 << (attempt - 1))) }
                guard let self, !Task.isCancelled else { return }
                guard self.sameKhmerDeleteCaret(caret) else { break }
                if let confirmed = self.observedKhmerDelete(before: before, end: end, live: self.target.documentContextBeforeInput) {
                    // With no right-hand context a cursor move can also reveal a shorter prefix.
                    // Only a scalar or a whole grapheme can confirm the one outstanding Backspace.
                    if caret.after == nil, self.target.hasText, let last = before.last {
                        let removed = end - confirmed.end
                        let cluster = String(last)
                        guard removed == cluster.utf16.count || removed == cluster.unicodeScalars.last?.utf16.count else { break }
                    }
                    let removed = String(decoding: original.dropFirst(confirmed.end), as: UTF16.self)
                    self.finishKhmerDeleteRecovery(restoring: removed, at: caret)
                    return
                }
                if attempt == 4, let live = self.target.documentContextBeforeInput,
                   live.utf16.elementsEqual(before.utf16) {
                    // The host still has the last confirmed spelling. Restore only the
                    // characters known to have been removed.
                    let removed = String(decoding: original.dropFirst(end), as: UTF16.self)
                    self.finishKhmerDeleteRecovery(restoring: removed, at: caret)
                    return
                }
            }
            self?.finishKhmerDeleteRecovery(at: caret)
        })
    }

    private func finishKhmerDeleteRecovery(restoring restored: String? = nil, at caret: KhmerDeleteCaret,
                                           applyPick: (() -> Void)? = nil) {
        guard !Task.isCancelled, let input = khmerDeleteRecovery?.input else { return }
        khmerDeleteRecovery = nil
        forgetTypingContext()
        guard let restored, sameKhmerDeleteCaret(caret) else {
            didEdit()
            return
        }
        if !restored.isEmpty { target.insertText(restored) }
        applyPick?()
        // An insertion may trigger a synchronous focus or route change.
        if !input.isEmpty, sameKhmerDeleteCaret(caret) {
            insert(input, source: "key")
        } else {
            didEdit()
        }
    }

    /// One word and its trailing punctuation. In a connected Khmer run, use only word
    /// boundaries supported by the same dictionary as completions and spelling fixes.
    func khmerWordToDelete(before: String) -> String? {
        let (words, trailing) = DeleteWordSwipe.splitTrailingSeparators(in: before)
        if KhmerAutocomplete.endsWithWordText(words) {
            guard !KhmerAutocomplete.startsWithWordText(target.documentContextAfterInput),
                  let suffix = khmerAutocomplete?.wordSuffix(in: words, personalWords: autocorrect.ownWords) else { return nil }
            return suffix + trailing
        }
        guard !words.isEmpty else { return trailing.isEmpty ? nil : String(trailing) }
        let count = DeleteWordSwipe.wordLength(before: String(words), stopsAtKhmer: true) ?? 0
        return String(words.suffix(count)) + trailing
    }

    func deleteKhmerWordBackward(before: String) {
        guard let suffix = khmerWordToDelete(before: before) else {
            deleteBackward(takesSwipeBack: false, source: "repeat_word")
            return
        }
        switch deleteKhmerWord(suffix, before: before, source: "repeat_word") {
        case .rejected:
            deleteBackward(takesSwipeBack: false, source: "repeat_word")
        case .interrupted:
            break
        case .removed:
            didEdit()
            typingLog?.context("delete_word")
        }
    }

    /// A gesture can save the suffix for restoration only after the proxy confirms its removal.
    func deleteKhmerWord(_ suffix: String, before: String, source: String) -> KhmerSuffixDeletion {
        let deletion = deleteKhmerSuffix(SmartPunctuation.plain(suffix), from: SmartPunctuation.plain(before))
        guard case .removed = deletion else { return deletion }
        forgetTextAroundKeys()
        learning?.willErase(word: suffix)
        tokenTaps.removeAll()
        lastSpaceAt = nil
        typingLog?.edit("delete_word", [
            TypingLogField("deleted", .string(suffix)),
            TypingLogField("src", .string(source)),
        ])
        return deletion
    }
}
