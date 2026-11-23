import UIKit
import XCTest
@testable import HEX

extension FullKeyboardEngineTests {
    func testKhmerAutocompleteWorksWithAutocorrectOffAndAppendsOnlyTheMissingScalars() async throws {
        engine.language = .khmer
        engine.autocorrect.isEnabled = false
        await engine.khmerAutocompleteLoad?.value
        for character in ["ក", "ម", "្"] { tap(.character(character)) }
        XCTAssertEqual(target.text, "កម្")
        let completion = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(completion.kind, .khmerCompletion)
        XCTAssertEqual(completion.displayText, "កម្ពុជា")
        XCTAssertEqual(completion.replacement, "ពុជា")
        XCTAssertFalse(completion.willAutoReplace)

        engine.acceptSuggestion(completion)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), "កម្ពុជា".unicodeScalars.map(\.value))
        engine.acceptSuggestion(completion)
        XCTAssertEqual(target.text, "កម្ពុជា")
    }

    func testKhmerAutocompleteConditionsAndStalePicks() async throws {
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        target.insertText("កម្")
        engine.textDidChange()
        let completion = try XCTUnwrap(engine.suggestions.first)

        target.selectedText = "ក"
        engine.acceptSuggestion(completion)
        XCTAssertEqual(target.text, "កម្")
        XCTAssertTrue(engine.suggestions.isEmpty)

        target.selectedText = nil
        target.autocorrectionType = .no
        engine.textDidChange()
        XCTAssertTrue(engine.suggestions.isEmpty)
        target.autocorrectionType = .default
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.isEmpty)

        target.insertText("។")
        engine.acceptSuggestion(completion)
        XCTAssertEqual(target.text, "កម្។")
        XCTAssertTrue(engine.suggestions.isEmpty)

        target.deleteBackward()
        engine.textDidChange()
        tap(.space)
        XCTAssertEqual(target.text, "កម្ ")
        XCTAssertTrue(engine.suggestions.isEmpty)

        target.deleteBackward()
        target.insertText("ជ")
        target.adjustTextPosition(byCharacterOffset: -1)
        engine.textDidChange()
        XCTAssertEqual(target.documentContextBeforeInput, "កម្")
        XCTAssertTrue(engine.suggestions.isEmpty, "The caret is inside a Khmer word")
    }

    func testKhmerAutocorrectOnSpaceAndRevert() async throws {
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        target.insertText("ចំនុច")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.map(\.displayText), ["“ចំនុច”", "ចំណុច"])
        XCTAssertEqual(engine.suggestions.map(\.willAutoReplace), [false, true])

        tap(.space)
        XCTAssertEqual(target.text, "ចំណុច")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "ចំនុច")
        tap(.space)
        XCTAssertEqual(target.text, "ចំនុច ")
    }

    func testKhmerAutocorrectReplacesAndRevertsWhenHostDeletesScalars() async throws {
        target = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "ខ្ញុំចំណុច")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "ខ្ញុំចំនុច")
    }

    func testKhmerCorrectionReadsThroughTransientStaleAndUnavailableContext() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 2
        target = textTarget
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "ខ្ញុំចំណុច")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "ខ្ញុំចំនុច")
    }

    func testKhmerCorrectionWaitsForTheHostToConfirmTheDeleteBeforeRestoring() async {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "ចំណុច")
        tap(.space)
        XCTAssertNotNil(engine.khmerDeleteRecovery)
        await engine.khmerDeleteRecovery?.task.value

        XCTAssertEqual(target.text, "ខ្ញុំចំនុច ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerAutocorrectPreservesTextWithoutADocumentIdentifier() async {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)

        XCTAssertEqual(target.text, "ខ្ញុំចំនុច ")
        XCTAssertNil(engine.khmerDeleteRecovery)
    }

    func testKhmerDeleteRecoveryDoesNotWriteAfterTheFieldChanges() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
        target.documentIdentifier = UUID()
        let nextFieldText = target.text

        await recovery.task.value

        XCTAssertEqual(target.text, nextFieldText)
    }

    func testFreshKeyInAnotherFieldIsIndependentOfPendingKhmerDeleteRecovery() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
        target.documentIdentifier = UUID()
        let nextFieldText = target.text

        tap(.character("ក"))
        XCTAssertEqual(target.text, nextFieldText + "ក")
        await recovery.task.value

        XCTAssertEqual(target.text, nextFieldText + "ក")
    }

    func testKhmerDeleteRecoveryDoesNotWriteAfterRoutingThroughEmojiSearch() async throws {
        for leavesSearchOpen in [true, false] {
            let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
            textTarget.laggingReadsAfterDeleting = 6
            textTarget.documentIdentifier = UUID()
            textTarget.hidesAfterText = true
            let routedTarget = EmojiRoutedTarget(document: textTarget)
            engine = FullKeyboardEngine(target: routedTarget, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
            engine.language = .khmer
            await engine.khmerAutocompleteLoad?.value

            tap(.space)
            let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
            let hostText = textTarget.text
            routedTarget.query = ""
            if !leavesSearchOpen { routedTarget.query = nil }

            await recovery.task.value

            XCTAssertEqual(routedTarget.query, leavesSearchOpen ? "" : nil)
            XCTAssertEqual(textTarget.text, hostText)
        }
    }

    func testKhmerWordDeletionUsesTheEstablishedJoinedBoundary() async {
        target = KhmerScalarDeletingTarget(text: "ខ្ញុំទៅសាលា។ ")
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        let slide = DeleteWordSwipe(engine: engine, touchID: 1, startX: 0)
        let step = engine.layout.letterWidth
        XCTAssertTrue(slide.move(to: -step * 1.2))
        XCTAssertEqual(slide.deletedWordCount, 1)
        XCTAssertEqual(target.text, "ខ្ញុំទៅ")
        XCTAssertTrue(slide.move(to: 0))
        XCTAssertEqual(target.text, "ខ្ញុំទៅសាលា។ ")
        slide.finish()

        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)
        XCTAssertEqual(target.text, "ខ្ញុំទៅ")
    }

    func testKhmerDeleteSwipeStopsAfterTheCaretMovesOrTheDocumentChanges() async {
        for movesCaret in [true, false] {
            let field = KhmerScalarDeletingTarget(text: "ខ្ញុំទៅសាលា")
            field.documentIdentifier = UUID()
            engine = FullKeyboardEngine(target: field)
            engine.language = .khmer
            await engine.khmerAutocompleteLoad?.value
            let swipe = DeleteWordSwipe(engine: engine, touchID: 1, startX: 0)
            let step = engine.layout.letterWidth
            XCTAssertTrue(swipe.move(to: -step * 1.2))
            XCTAssertEqual(field.text, "ខ្ញុំទៅ")

            if movesCaret {
                field.adjustTextPosition(byCharacterOffset: -1)
            } else {
                field.documentIdentifier = UUID()
            }
            XCTAssertTrue(swipe.move(to: 0))
            XCTAssertTrue(swipe.move(to: -step * 3))
            XCTAssertEqual(field.text, "ខ្ញុំទៅ")
        }
    }

    func testKhmerDeleteSwipeRestoresWordsThroughBoundedOrLaggingContext() async {
        for report in KhmerRestoreReportingTarget.Report.allCases {
            let prefix = report == .codeUnits ? "abcdefghijk " : "សាលា"
            let full = prefix + "ខ្ញុំទៅបាន"
            let field = KhmerRestoreReportingTarget(text: full + "ក")
            field.documentIdentifier = UUID()
            engine = FullKeyboardEngine(target: field)
            engine.language = .khmer
            await engine.khmerAutocompleteLoad?.value
            let plane = KeyboardKeyPlaneView(engine: engine)
            let step = engine.layout.letterWidth
            plane.began(id: 1, sample: deleteSample(engine))
            XCTAssertEqual(field.text, full, "The initial Backspace press deletes one character")
            plane.moved(id: 1, sample: deleteSample(engine, dx: -step * 3.2))
            XCTAssertEqual(field.text, prefix)
            field.reportAfterInsert = report

            plane.moved(id: 1, sample: deleteSample(engine, dx: -step * 2.2))
            XCTAssertEqual(field.text, prefix + "ខ្ញុំ")
            if report == .oldPrefix || report == .unavailable {
                plane.moved(id: 1, sample: deleteSample(engine))
                XCTAssertEqual(field.text, prefix + "ខ្ញុំ", "An unconfirmed restore must not authorize another write")
                field.reportAfterInsert = nil
            } else {
                plane.moved(id: 1, sample: deleteSample(engine))
            }
            plane.ended(id: 1, sample: deleteSample(engine))
            XCTAssertEqual(field.text, full)
        }
    }

    func testKhmerWordSwipePreservesPrefixWhenTheHostHidesAnEmptyPrefix() async {
        let field = KhmerHiddenEmptyPrefixTarget(text: "សាលា។")
        field.documentIdentifier = UUID()
        field.adjustTextPosition(byCharacterOffset: -1)
        engine = FullKeyboardEngine(target: field, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        let slide = DeleteWordSwipe(engine: engine, touchID: 1, startX: 0)
        XCTAssertTrue(slide.move(to: -engine.layout.letterWidth * 1.2))
        XCTAssertEqual(slide.deletedWordCount, 0)
        XCTAssertNil(engine.khmerDeleteRecovery)
        XCTAssertEqual(field.text, "សាលា។")
    }

    func testHeldKhmerBackspaceFallsBackToOneDeleteAtARejectedBoundary() async {
        let field = KhmerHiddenEmptyPrefixTarget(text: "សាលា។")
        field.documentIdentifier = UUID()
        field.adjustTextPosition(byCharacterOffset: -1)
        engine = FullKeyboardEngine(target: field, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)

        XCTAssertNil(engine.khmerDeleteRecovery)
        XCTAssertEqual(field.text, String("សាលា".dropLast()) + "។")
    }

    func testKhmerWordDeletionStopsAtTheLatinBoundary() async {
        target = KhmerScalarDeletingTarget(text: "សាលាabc")
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        engine.deleteWordBackward()
        XCTAssertEqual(target.text, "សាលា")
        engine.deleteWordBackward()
        XCTAssertEqual(target.text, "")
    }

    func testKhmerCorrectionUndoStaysInItsOwnDocument() async throws {
        target = FixtureTextTarget(text: "ចំនុច")
        let originalDocument = UUID()
        target.documentIdentifier = originalDocument
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "ចំណុច")
        let undo = try XCTUnwrap(engine.suggestions.first { $0.kind == .revert })
        target.documentIdentifier = UUID()
        engine.acceptSuggestion(undo)
        XCTAssertEqual(target.text, "ចំណុច")
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })

        target.documentIdentifier = originalDocument
        engine.textDidChange()
        engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.kind == .revert }))
        XCTAssertEqual(target.text, "ចំនុច")
    }

    func testKhmerCorrectionDoesNotRewriteOrOfferUndoWithoutADocumentIdentifier() async {
        target.insertText("ចំនុច")
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "ចំនុច ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerWordDeletionLeavesAnIncompleteRunToNormalBackspace() async {
        target = KhmerScalarDeletingTarget(text: "ខ្ញុំស្")
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        let slide = DeleteWordSwipe(engine: engine, touchID: 1, startX: 0)
        XCTAssertTrue(slide.move(to: -engine.layout.letterWidth * 1.2))
        XCTAssertEqual(slide.deletedWordCount, 0)
        XCTAssertEqual(target.text, "ខ្ញុំស្")

        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)
        XCTAssertEqual(target.text, "ខ្ញុំស")
    }

    func testKhmerCorrectionRestoresExactTextWhenHostDeletesAcrossTheBoundary() async {
        target = KhmerOverDeletingTarget(text: "“ ចំនុច")
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "ចំណុច")
        tap(.space)
        XCTAssertEqual(target.text, "“ ចំនុច ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerCorrectionRestoresConfirmedDeletesWhenTheHostStopsDeleting() async {
        target = KhmerStopsDeletingTarget(text: "ខ្ញុំចំនុច")
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "ចំណុច")
        tap(.space)
        await engine.khmerDeleteRecovery?.task.value
        XCTAssertEqual(target.text, "ខ្ញុំចំនុច ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerDictionaryAutocorrectRemovesADoubledVowelAfterAKnownWord() async throws {
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        target.insertText("ខ្ញុំសាាលា")
        engine.textDidChange()
        let correction = try XCTUnwrap(engine.suggestions.first(where: \.willAutoReplace))
        XCTAssertEqual(correction.displayText, "សាលា")

        tap(.space)
        XCTAssertEqual(target.text, "ខ្ញុំសាលា")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "ខ្ញុំសាាលា")
    }

    func testKhmerDictionarySpellingGuessRequiresATap() async throws {
        engine.language = .khmer
        target.documentIdentifier = UUID()
        await engine.khmerAutocompleteLoad?.value
        target.insertText("សួស្ដី")
        engine.textDidChange()
        let suggestion = try XCTUnwrap(engine.suggestions.first { $0.kind == .khmerCorrection(autoReplace: false) })
        XCTAssertEqual(suggestion.displayText, "សួស្តី")
        XCTAssertFalse(suggestion.willAutoReplace)

        tap(.space)
        engine.acceptSuggestion(suggestion)
        XCTAssertEqual(target.text, "សួស្ដី ")
        engine.deleteBackward()
        engine.acceptSuggestion(suggestion)
        XCTAssertEqual(target.text, "សួស្តី")
    }

    func testKhmerSpatialSuggestionsRankRealTapsOnBothLayouts() async throws {
        for (letters, neighbor, replacement) in [
            (KeyboardLetterLayout.khmer, "ន", "មាន់"),
            (.khmerism, "ត", "មាត់"),
        ] {
            for (enabled, pick) in [(false, false), (true, false), (true, true)] {
                smartField(language: .khmer)
                target.documentIdentifier = UUID()
                engine.letterLayout = letters
                engine.khmerismSmartMode = true
                engine.khmerSpatialSuggestions = enabled
                await engine.khmerAutocompleteLoad?.value
                let journalSettings = TypingJournalSettings(defaults: defaults)
                journalSettings.isEnabled = true
                let journal = TypingJournal(directory: nil, settings: journalSettings)
                engine.journal = journal
                if pick {
                    target.insertText("មាប់")
                    engine.textDidChange()
                    for _ in "មាប់" { engine.deleteBackward() }
                    XCTAssertEqual(target.text, "")
                }

                tap(.character("ម"))
                tap(.character("ា"))
                let literal = point(.character("ប"))
                let alternative = point(.character(neighbor))
                tapAt(CGPoint(x: literal.x + 0.49 * (alternative.x - literal.x), y: literal.y))
                tap(.character("់"))

                XCTAssertEqual(target.text, "មាប់")
                let choice = try XCTUnwrap(engine.suggestions.first { $0.kind == .khmerCorrection(autoReplace: false) })
                XCTAssertEqual(choice.replacement, enabled ? replacement : "ចាប់")
                if pick {
                    engine.acceptSuggestion(choice)
                    XCTAssertEqual(target.text, replacement)
                    tap(.space)
                    XCTAssertTrue(journal.current.corrections.isEmpty)
                } else {
                    tap(.space)
                    XCTAssertEqual(target.text, "មាប់ ")
                }
            }
        }
    }

    func testKhmerSpaceRestoresAMissingCoengAndKeepsTheNextWordJoined() async throws {
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        target.insertText("កមពុជា")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "កម្ពុជា")

        tap(.space)
        XCTAssertEqual(target.text, "កម្ពុជា")
        XCTAssertEqual(engine.suggestions.first?.kind, .revert)
        target.insertText("ទៅ")
        engine.textDidChange()
        XCTAssertEqual(target.text, "កម្ពុជាទៅ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerSpaceCorrectsSchoolThenCanInsertADeliberateSpace() async throws {
        target.documentIdentifier = UUID()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        target.insertText("សាលារ")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "សាលា")

        tap(.layerSwitch(.numbers))
        tap(.space)
        XCTAssertEqual(target.text, "សាលា")
        XCTAssertEqual(engine.layout.layer, .letters)
        XCTAssertEqual(engine.suggestions.first?.kind, .revert)
        tap(.space)
        XCTAssertEqual(target.text, "សាលា ")

        target.insertText("សាលារៀន")
        engine.textDidChange()
        tap(.space)
        XCTAssertEqual(target.text, "សាលា សាលារៀន ")
    }

    func testKhmerAutocorrectOnPunctuationAndExplicitPick() async throws {
        useKhmerism()
        await engine.khmerAutocompleteLoad?.value
        target.insertText("ចំនុច")
        engine.textDidChange()
        tap(.shift)
        tap(.character("ំ"))
        XCTAssertEqual(target.text, "ចំណុច។")

        target.insertText("ចំនុច")
        engine.textDidChange()
        let correction = try XCTUnwrap(engine.suggestions.first(where: \.willAutoReplace))
        engine.acceptSuggestion(correction)
        XCTAssertEqual(target.text, "ចំណុច។ចំណុច")
    }

    func testKhmerAutocorrectHonorsKeepAndTheAutocorrectSwitch() async throws {
        engine.language = .khmer
        target.documentIdentifier = UUID()
        await engine.khmerAutocompleteLoad?.value
        engine.autocorrect.isEnabled = false
        target.insertText("ចំនុច")
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
        tap(.space)
        XCTAssertEqual(target.text, "ចំនុច ")

        engine.autocorrect.isEnabled = true
        target.insertText("ចំនុច")
        engine.textDidChange()
        let keep = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(keep.kind, .khmerKeepLiteral)
        engine.acceptSuggestion(keep)
        XCTAssertEqual(target.text, "ចំនុច ចំនុច")
        XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
        tap(.space)
        XCTAssertEqual(target.text, "ចំនុច ចំនុច ")
    }
}

@MainActor
private final class KhmerHiddenEmptyPrefixTarget: FixtureTextTarget {
    override var documentContextBeforeInput: String? {
        let before = super.documentContextBeforeInput
        return before?.isEmpty == false ? before : nil
    }
}

/// Matches the UIKit host that removes Khmer combining marks one scalar at a time.
@MainActor
final class KhmerScalarDeletingTarget: FixtureTextTarget {
    var laggingReadsAfterDeleting = 0
    private var pendingReports: [String?] = []

    override var documentContextBeforeInput: String? {
        if !pendingReports.isEmpty { return pendingReports.removeFirst() }
        return super.documentContextBeforeInput
    }

    override func deleteBackward() {
        guard let previous = super.documentContextBeforeInput, let cluster = previous.last else { return }
        super.deleteBackward()
        super.insertText(String(String(cluster).unicodeScalars.dropLast()))
        pendingReports = (0..<laggingReadsAfterDeleting).map { $0.isMultiple(of: 2) ? previous : nil }
    }
}

@MainActor
private final class KhmerRestoreReportingTarget: FixtureTextTarget {
    enum Report: CaseIterable { case characters, codeUnits, oldPrefix, unavailable }
    var reportAfterInsert: Report?
    private var echo: String?

    override var documentContextBeforeInput: String? {
        let before = super.documentContextBeforeInput
        guard let echo, let before else { return before }
        switch reportAfterInsert {
        case .characters: return String(before.suffix(echo.count))
        case .codeUnits: return String(decoding: before.utf16.suffix(echo.utf16.count), as: UTF16.self)
        case .oldPrefix: return echo
        case .unavailable: return nil
        case nil: return before
        }
    }

    override func insertText(_ text: String) {
        echo = super.documentContextBeforeInput
        super.insertText(text)
    }
}

@MainActor
private final class KhmerOverDeletingTarget: FixtureTextTarget {
    override func deleteBackward() {
        super.deleteBackward()
        if super.documentContextBeforeInput == "“ ចំ" {
            super.deleteBackward()
            super.deleteBackward()
        }
    }
}

@MainActor
private final class KhmerStopsDeletingTarget: FixtureTextTarget {
    private var deletes = 0

    override func deleteBackward() {
        deletes += 1
        if deletes == 1 { super.deleteBackward() }
    }
}

@MainActor
final class KhmerNilBeforeStartTarget: FixtureTextTarget {
    override var documentContextBeforeInput: String? {
        guard cursorIndex > 0 else { return nil }
        return super.documentContextBeforeInput
    }
}
