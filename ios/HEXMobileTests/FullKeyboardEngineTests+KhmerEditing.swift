import UIKit
import XCTest
@testable import HEX

extension FullKeyboardEngineTests {
    func testKhmerLearningExportIncludesAllRetainedCounts() throws {
        var learning = KhmerSuggestionLearning()
        learning.record("សូម", after: nil)
        learning.record("អរគុណ", after: "សូម")
        learning.record("សូម", after: nil)

        let document = try KhmerLearningDocument(learning: learning)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: document.data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["words", "pairs"])
        XCTAssertEqual(json["words"] as? [String: Int], ["សូម": 2, "អរគុណ": 1])
        XCTAssertEqual(json["pairs"] as? [String: [String: Int]], ["សូម": ["អរគុណ": 1]])
    }

    func testKhmerPersonalSuggestionsLearnJoinedTypingAndPersistOnBothLayouts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = TypingJournalSettings(defaults: defaults)
        let index = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100\nសូម\t90\nសុខ\t10")
        XCTAssertFalse(FullKeyboardSettings(defaults: defaults).khmerPersonalSuggestions)

        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            TypingJournal.delete(in: directory, settings: settings)
            smartField(language: .khmer)
            target.documentIdentifier = UUID()
            engine.letterLayout = letters
            await engine.khmerAutocompleteLoad?.value
            engine.khmerAutocomplete = index
            engine.autocorrect.isEnabled = false
            engine.journal = TypingJournal(directory: directory, settings: settings)
            engine.khmerPersonalSuggestions = true

            // Existing host text followed by a space does not teach a word.
            target.insertText("ខ្ញុំសុខ")
            engine.textDidChange()
            tap(.space)
            XCTAssertTrue(try XCTUnwrap(engine.journal).khmerSuggestions.isEmpty)
            tap(.returnKey)

            for _ in 0..<2 {
                for unit in "ខ្ញុំសុខ".unicodeScalars {
                    engine.insertKhmerKeyText(String(unit), source: "key")
                }
                tap(.returnKey)
            }

            let reloaded = TypingJournal(directory: directory, settings: settings)
            engine.journal = reloaded
            XCTAssertEqual(reloaded.khmerSuggestions.preferredWords(after: "ខ្ញុំ"), ["សុខ"])
            engine.insertKhmerKeyText("ស", source: "key")
            XCTAssertEqual(engine.suggestions.first?.displayText, "សុខ")
            tap(.delete)
            let first = try XCTUnwrap(engine.suggestions.first { $0.displayText == "ខ្ញុំ" })
            engine.acceptSuggestion(first)
            XCTAssertEqual(engine.suggestions.first?.displayText, "សុខ")
            engine.insertKhmerKeyText("ស", source: "key")
            XCTAssertEqual(engine.suggestions.first?.displayText, "សុខ")
            XCTAssertFalse(try XCTUnwrap(engine.suggestions.first).willAutoReplace)

            engine.khmerPersonalSuggestions = false
            XCTAssertEqual(engine.suggestions.first?.displayText, "សូម")
            engine.khmerPersonalSuggestions = true
            TypingJournal.delete(in: directory, settings: settings)
            engine.refreshSuggestions()
            XCTAssertTrue(reloaded.khmerSuggestions.isEmpty)
            XCTAssertEqual(engine.suggestions.first?.displayText, "សូម")
        }
    }

    func testKhmerPersonalSuggestionsLearnFromPicksInEligibleFields() async throws {
        smartField(language: .khmer)
        await engine.khmerAutocompleteLoad?.value
        target.documentIdentifier = UUID()
        let journal = TypingJournal(directory: nil, settings: TypingJournalSettings(defaults: defaults))
        engine.journal = journal
        engine.khmerPersonalSuggestions = true
        for _ in 0..<2 {
            for word in ["សូម", "អរគុណ"] {
                engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == word }))
            }
            tap(.returnKey)
        }
        XCTAssertEqual(journal.khmerSuggestions.preferredWords(after: "សូម"), ["អរគុណ"])

        let learned = journal.khmerSuggestions
        target.isSecureTextEntry = true
        engine.configureForField()
        for unit in "ខ្ញុំ".unicodeScalars {
            engine.insertKhmerKeyText(String(unit), source: "key")
        }
        tap(.returnKey)
        XCTAssertEqual(journal.khmerSuggestions, learned)
    }

    private func loadKhmerKeyboard(for field: KeyboardTextTarget) async {
        let autocorrect = AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults))
        engine = FullKeyboardEngine(target: field, autocorrect: autocorrect)
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
    }

    func testKhmerStartersAndJoinedNextWordsOnBothLayouts() throws {
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField()
            target.documentIdentifier = UUID()
            engine.autocorrect.isEnabled = false
            engine.language = .khmer
            engine.letterLayout = letters
            let starters = ["ខ្ញុំ", "សូម", "តើ"]
            // A newly opened keyboard can show starters before the dictionary load completes.
            XCTAssertEqual(engine.suggestions.map(\.displayText), starters)
            let first = try XCTUnwrap(engine.suggestions.first)
            engine.acceptSuggestion(first)
            XCTAssertEqual(target.text, "ខ្ញុំ")
            engine.textDidChange() // UIKit echoes the keyboard's own insertion.
            let continuation = try XCTUnwrap(engine.suggestions.first { $0.displayText == "ចង់" })
            XCTAssertFalse(continuation.willAutoReplace)
            engine.acceptSuggestion(continuation)
            XCTAssertEqual(target.text, "ខ្ញុំចង់")
            if letters == .khmerism { tap(.shift) }
            tap(.character(letters == .khmerism ? "ំ" : "។"))
            XCTAssertEqual(engine.suggestions.map(\.displayText), starters)
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first))
            XCTAssertEqual(target.text, "ខ្ញុំចង់។ខ្ញុំ")
        }
    }

    func testKhmerEnglishExperimentOffersOneTapOnlySuggestionOnBothLayouts() async throws {
        XCTAssertFalse(FullKeyboardSettings(defaults: defaults).khmerEnglishSuggestions)
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            engine.letterLayout = letters
            target.documentIdentifier = UUID()
            await engine.khmerAutocompleteLoad?.value

            target.insertText("ណូត")
            engine.textDidChange()
            XCTAssertFalse(engine.suggestions.contains { $0.displayText == "note" })
            engine.khmerEnglishSuggestions = true
            let note = try XCTUnwrap(engine.suggestions.first { $0.displayText == "note" })
            XCTAssertEqual(note.kind, .khmerEnglish(typed: "ណូត"))
            XCTAssertFalse(note.willAutoReplace)
            tap(.space)
            XCTAssertEqual(target.text, "ណូត ")
            engine.acceptSuggestion(note)
            XCTAssertEqual(target.text, "ណូត ")

            target.insertText("កុំព្យូទ័រ")
            engine.textDidChange()
            let computer = try XCTUnwrap(engine.suggestions.first { $0.displayText == "computer" })
            XCTAssertLessThanOrEqual(engine.suggestions.count, 3)
            engine.acceptSuggestion(computer)
            XCTAssertEqual(target.text, "ណូត computer")
            XCTAssertEqual(engine.layout.language, .khmer)
        }
    }

    func testKhmerEnglishExperimentSkipsAmbiguousPrefixesAndRejectsStaleField() async throws {
        smartField(language: .khmer)
        target.documentIdentifier = UUID()
        await engine.khmerAutocompleteLoad?.value
        engine.khmerEnglishSuggestions = true

        target.insertText("ស្កេ")
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.contains { $0.displayText == "scan" || $0.displayText == "scanner" })
        target.insertText(" វ៉ាយហ្វ")
        engine.textDidChange()
        let wifi = try XCTUnwrap(engine.suggestions.first { $0.displayText == "Wi-Fi" })
        target.documentIdentifier = UUID()
        engine.acceptSuggestion(wifi)
        XCTAssertEqual(target.text, "ស្កេ វ៉ាយហ្វ")

        target.insertText(" តេឡេក្រាម")
        engine.textDidChange()
        engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "Telegram" }))
        XCTAssertEqual(target.text, "ស្កេ វ៉ាយហ្វ Telegram")
    }

    func testKhmerEnglishExperimentOffersBothSpellingsInSearchWithAutocorrectionDisabled() async throws {
        for (layout, keyboardType, choice) in [
            (KeyboardLetterLayout.khmer, UIKeyboardType.default, "Telegram"),
            (.khmerism, .webSearch, "តេឡេក្រាម"),
        ] {
            smartField(language: .khmer)
            engine.letterLayout = layout
            target.documentIdentifier = UUID()
            target.keyboardType = keyboardType
            target.returnKeyType = .search
            target.autocorrectionType = .no
            engine.configureForField()
            await engine.khmerAutocompleteLoad?.value
            engine.khmerEnglishSuggestions = true

            target.insertText("តេឡេក្")
            engine.textDidChange()
            XCTAssertEqual(engine.suggestions.map(\.displayText), ["តេឡេក្រាម", "Telegram"])
            XCTAssertTrue(engine.suggestions.allSatisfy { !$0.willAutoReplace })
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == choice }))
            XCTAssertEqual(target.text, choice)
            XCTAssertEqual(engine.letterLayout, layout)
        }
    }

    func testEnglishPickPreservesTextRevealedByABoundedCaretWindow() async throws {
        for prefix in ["a", "abc", "🙂"] {
            let field = KhmerBoundedCaretTarget(text: prefix + "ណូត!")
            field.documentIdentifier = UUID()
            field.adjustTextPosition(byCharacterOffset: -1)
            await loadKhmerKeyboard(for: field)
            engine.khmerEnglishSuggestions = true
            let note = try XCTUnwrap(engine.suggestions.first { $0.displayText == "note" })
            engine.acceptSuggestion(note)
            await engine.khmerDeleteRecovery?.task.value
            XCTAssertEqual(field.text, prefix + "note!")
            XCTAssertEqual(field.cursorIndex, prefix.count + "note".count)
        }
    }

    func testEnglishPickOnlyReplacesTheLastJoinedLoanword() async throws {
        let field = FixtureTextTarget(text: "ម៉ៅស៍កុំព្យូទ័រ!")
        field.documentIdentifier = UUID()
        field.adjustTextPosition(byCharacterOffset: -1)
        await loadKhmerKeyboard(for: field)
        engine.khmerEnglishSuggestions = true
        engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "computer" }))
        XCTAssertEqual(field.text, "ម៉ៅស៍computer!")
    }

    func testEnglishAppCompletionKeepsTheLeadingKhmerChoice() async throws {
        for layout in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            engine.letterLayout = layout
            target.documentIdentifier = UUID()
            await engine.khmerAutocompleteLoad?.value
            target.insertText("ស្លា")
            engine.textDidChange()
            let ordinary = try XCTUnwrap(engine.suggestions.first)

            engine.khmerEnglishSuggestions = true
            XCTAssertTrue(engine.suggestions.contains(ordinary))
            XCTAssertTrue(engine.suggestions.contains { $0.displayText == "ស្លាក់" })
            XCTAssertTrue(engine.suggestions.contains { $0.displayText == "Slack" })
            engine.acceptSuggestion(ordinary)
            XCTAssertEqual(target.text, ordinary.displayText)
        }
    }

    func testEnglishPickBeforePunctuationPreservesTheFollowingText() async throws {
        let tail = ". Next"
        for field in [FixtureTextTarget(), KhmerNilBeforeStartTarget()] {
            field.documentIdentifier = UUID()
            await loadKhmerKeyboard(for: field)
            engine.khmerEnglishSuggestions = true
            field.insertText("ណូត" + tail)
            field.adjustTextPosition(byCharacterOffset: -tail.count)
            engine.textDidChange()
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "note" }))
            await engine.khmerDeleteRecovery?.task.value
            XCTAssertEqual(field.documentContextBeforeInput, "note")
            XCTAssertEqual(field.documentContextAfterInput, tail)
        }
    }

    func testEnglishPickChecksForCursorMovementBeforeDeleting() async throws {
        for (tail, ignoresForward) in [("!", true), ("👩🏽‍💻 tonight", false), ("e\u{301} later", false)] {
            let field = KhmerBoundedCaretTarget(text: "ណូត" + tail)
            field.documentIdentifier = UUID()
            field.adjustTextPosition(byCharacterOffset: -tail.count)
            field.ignoresForward = ignoresForward
            await loadKhmerKeyboard(for: field)
            engine.khmerEnglishSuggestions = true
            let pick = try XCTUnwrap(engine.suggestions.first { $0.displayText == "note" })
            engine.acceptSuggestion(pick)
            if ignoresForward {
                tap(.character("ក"))
                XCTAssertEqual(engine.khmerDeleteRecovery?.input, "ក")
            }
            await engine.khmerDeleteRecovery?.task.value

            let prefix = ignoresForward ? "ណូតក" : "note"
            XCTAssertEqual(field.text, prefix + tail)
            XCTAssertEqual(field.cursorIndex, prefix.count)
        }
    }

    func testEnglishPickReturnsFromAProbeThatHidesTheWholePrefix() async throws {
        let field = KhmerBoundedCaretTarget(text: "ផៅ!")
        field.leftWindow = 1
        field.documentIdentifier = UUID()
        field.adjustTextPosition(byCharacterOffset: -1)
        await loadKhmerKeyboard(for: field)
        engine.khmerEnglishSuggestions = true
        engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "PowerPoint" }))
        let pending = try XCTUnwrap(engine.khmerDeleteRecovery)
        tap(.character("ក"))
        await pending.task.value
        XCTAssertEqual(field.text, "ផៅក!")
        XCTAssertEqual(field.cursorIndex, "ផៅក".count)
    }

    func testEnglishPickCompletesDelayedCaretProbesBeforeReplayingKeys() async throws {
        for delayedProbe in [1, 2] { // Before deleting, or verifying the last delete.
            for hidesContext in [false, true] {
                let field = KhmerDeferredCaretTarget(text: "ណូត. Next")
                field.documentIdentifier = UUID()
                field.adjustTextPosition(byCharacterOffset: -". Next".count)
                field.delayedProbe = delayedProbe
                field.hidesContext = hidesContext
                await loadKhmerKeyboard(for: field)
                engine.khmerEnglishSuggestions = true
                field.onDelayedForward = {
                    self.tap(.character("ក"))
                    XCTAssertEqual(self.engine.khmerDeleteRecovery?.input, "ក")
                }

                engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "note" }))
                let pending = try XCTUnwrap(engine.khmerDeleteRecovery)
                await pending.task.value

                XCTAssertNil(engine.khmerDeleteRecovery)
                XCTAssertEqual(field.documentContextBeforeInput, "noteក")
                XCTAssertEqual(field.documentContextAfterInput, ". Next")
                XCTAssertEqual(field.probeMoves, [1, -1, 1, -1])
            }
        }
    }

    func testKhmerEnglishExperimentStaysHiddenInRestrictedFields() async {
        smartField(language: .khmer)
        target.documentIdentifier = UUID()
        await engine.khmerAutocompleteLoad?.value
        engine.khmerEnglishSuggestions = true
        target.insertText("តេឡេក្")
        target.textContentType = .username
        engine.textDidChange()
        XCTAssertTrue(engine.suggestions.isEmpty)
        target.textContentType = nil
        target.isSecureTextEntry = true
        engine.textDidChange()
        XCTAssertTrue(engine.suggestions.isEmpty)
    }

    func testKhmerWordPairsAfterJoinedPicksOnBothLayouts() async throws {
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            engine.letterLayout = letters
            engine.autocorrect.isEnabled = false
            await engine.khmerAutocompleteLoad?.value

            for word in ["សូម", "អរគុណ"] {
                engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == word }))
            }
            XCTAssertEqual(target.text, "សូមអរគុណ")
            let next = try XCTUnwrap(engine.suggestions.first)
            XCTAssertEqual(next.displayText, "ច្រើន")
            XCTAssertEqual(next.kind, .khmerPrediction)
            XCTAssertFalse(next.willAutoReplace)

            tap(.character("ច"))
            let completion = try XCTUnwrap(engine.suggestions.first)
            XCTAssertEqual(completion.displayText, next.displayText)
            XCTAssertEqual(completion.kind, .khmerCompletion)
            engine.acceptSuggestion(completion)
            XCTAssertEqual(target.text, "សូមអរគុណច្រើន")
        }
    }

    func testKhmerWordPairsAfterTypedSeparatorsOnBothLayouts() async throws {
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            for separator in [" ", "\u{200B}"] {
                smartField(language: .khmer)
                engine.letterLayout = letters
                await engine.khmerAutocompleteLoad?.value
                target.insertText("ញ៉ាំ" + separator)
                engine.textDidChange()
                XCTAssertEqual(engine.suggestions.first?.displayText, "បាយ")

                tap(.character("ប"))
                let completion = try XCTUnwrap(engine.suggestions.first)
                XCTAssertEqual(completion.displayText, "បាយ")
                engine.acceptSuggestion(completion)
                XCTAssertEqual(target.text, "ញ៉ាំ" + separator + "បាយ")
            }
        }
    }

    func testExpandedKhmerCompletesAfterTwoScalarsOnBothLayouts() async throws {
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            engine.letterLayout = letters
            target.documentIdentifier = UUID()
            await engine.khmerAutocompleteLoad?.value
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "ខ្ញុំ" }))

            tap(.character("ប"))
            XCTAssertEqual(engine.suggestions.map(\.displayText), ["បាន", "បាទ", "ប្រាប់"])
            tap(.character("ា"))
            let completion = try XCTUnwrap(engine.suggestions.first { $0.displayText == "បានឃើញ" })
            XCTAssertEqual(completion.kind, .khmerCompletion)
            XCTAssertEqual(completion.replacement, "នឃើញ")
            XCTAssertFalse(completion.willAutoReplace)
            engine.acceptSuggestion(completion)
            XCTAssertEqual(target.text, "ខ្ញុំបានឃើញ")
        }
    }

    func testExpandedKhmerPreservesExistingSpellingRepairs() async throws {
        for (spelling, repaired, automatic) in [("ពិិនិត្យ", "ពិនិត្យ", true), ("ចំនុច", "ចំណុច", false)] {
            smartField(language: .khmer)
            target.documentIdentifier = UUID()
            await engine.khmerAutocompleteLoad?.value
            target.insertText(spelling)
            engine.textDidChange()
            let repair = try XCTUnwrap(engine.suggestions.first { $0.displayText == repaired })
            XCTAssertEqual(repair.kind, .khmerCorrection(autoReplace: automatic))
            tap(.space)
            XCTAssertEqual(target.text, automatic ? repaired : spelling + " ")
        }
    }

    /// Run this test alone in a fresh test-host process to measure cold initialization.
    /// The timings cover the strip's suggestion lookup on fixed synthetic text.
    func testKhmerSuggestionLookupMeasurements() async throws {
        func footprintMiB() throws -> Double {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
            let capacity = Int(count)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            return try XCTUnwrap(result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : nil)
        }

        target.documentIdentifier = UUID()
        let before = try footprintMiB()
        target.insertText("ខ្ញុំ បា")
        let start = CACurrentMediaTime()
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value
        XCTAssertFalse(engine.khmerSuggestionChoices(live: true).isEmpty)
        let load = (CACurrentMediaTime() - start) * 1_000
        let loaded = try footprintMiB()
        while target.hasText { target.deleteBackward() }

        var times: [Double] = []
        for sample in ["ខ្ញុំ ", "ខ្ញុំ ប", "ខ្ញុំ បា", "សូម ព្រ", "សាលារ", "កម្ពុ"] {
            target.insertText(sample)
            for _ in 0..<40 {
                let start = CACurrentMediaTime()
                _ = engine.khmerSuggestionChoices(live: true)
                times.append((CACurrentMediaTime() - start) * 1_000)
            }
            while target.hasText { target.deleteBackward() }
        }
        times.sort()
        print(String(
            format: "Khmer suggestions (test host) load %.2f ms, footprint %.2f → %.2f MiB (%+.2f), after queries %.2f MiB; lookup p50 %.3f ms, p95 %.3f ms (%d queries)",
            load, before, loaded, loaded - before, try footprintMiB(),
            times[times.count / 2], times[times.count * 95 / 100], times.count
        ))
    }

    func testKhmerCommonWordsFillSparsePredictionRows() async {
        smartField(language: .khmer)
        await engine.khmerAutocompleteLoad?.value
        target.insertText("នមោ ")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.first?.displayText, "តស្ស")

        target.insertText("ភគវតោ ")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.map(\.displayText), ["អរហតោ", "បាន", "មាន"])
    }

    func testKhmerFirstKeyAndWholeWordCompletionsOnBothLayouts() async throws {
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            target.documentIdentifier = UUID()
            engine.letterLayout = letters
            engine.autocorrect.isEnabled = false
            await engine.khmerAutocompleteLoad?.value
            tap(.character("ក"))
            XCTAssertEqual(engine.suggestions.map(\.displayText), ["ការ", "ក្នុង", "កម្ពុជា"])
            tap(.delete)
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "ខ្ញុំ" }))
            tap(.character("ក"))
            XCTAssertEqual(target.text, "ខ្ញុំក")
            let completion = try XCTUnwrap(engine.suggestions.first)
            XCTAssertEqual(completion.displayText, "ក៏")
            engine.acceptSuggestion(completion)
            XCTAssertEqual(target.text, "ខ្ញុំក៏")

            smartField(language: .khmer)
            engine.letterLayout = letters
            engine.autocorrect.isEnabled = false
            await engine.khmerAutocompleteLoad?.value
            tap(.character("ស"))
            tap(.character("ា"))
            XCTAssertEqual(target.text, "សា")
            let school = try XCTUnwrap(engine.suggestions.first { $0.displayText == "សាលា" })
            XCTAssertFalse(school.willAutoReplace)
            engine.acceptSuggestion(school)
            XCTAssertEqual(target.text, "សាលា")
        }
    }

    func testKhmerCompletionStartsJoinedPredictionAndRejectsStalePick() async throws {
        for moveToAnotherField in [false, true] {
            smartField(language: .khmer)
            target.documentIdentifier = UUID()
            await engine.khmerAutocompleteLoad?.value
            tap(.character("ខ"))
            tap(.character("្"))
            let completion = try XCTUnwrap(engine.suggestions.first { $0.displayText == "ខ្ញុំ" })
            engine.acceptSuggestion(completion)
            let next = try XCTUnwrap(engine.suggestions.first { $0.displayText == "ចង់" })
            if moveToAnotherField {
                target.documentIdentifier = UUID() // Same text and caret in another field.
            } else {
                target.adjustTextPosition(byCharacterOffset: -1)
            }
            engine.acceptSuggestion(next) // The host has yet to report the movement.
            XCTAssertEqual(target.text, "ខ្ញុំ")
            XCTAssertFalse(engine.suggestions.contains(next))
        }
    }

    func testKhmerPredictionsFollowAWindowedHostInALongMessage() async throws {
        let sentence = String(repeating: "សាលា", count: 12) + "។"
        for window in [KhmerRestoreReportingTarget.Report.characters, .codeUnits] {
            let field = KhmerRestoreReportingTarget(text: sentence)
            field.reportAfterInsert = window
            field.windowLimit = 16
            field.documentIdentifier = UUID()
            await loadKhmerKeyboard(for: field)
            engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.displayText == "ខ្ញុំ" }))
            engine.textDidChange()
            XCTAssertEqual(engine.suggestions.map(\.displayText), ["ចង់", "មាន", "នឹង"])

            tap(.character("ច"))
            XCTAssertEqual(field.text, sentence + "ខ្ញុំច")
            let completion = try XCTUnwrap(engine.suggestions.first)
            XCTAssertEqual(completion.displayText, "ចង់")
            engine.acceptSuggestion(completion)
            engine.textDidChange()
            let continuation = try XCTUnwrap(engine.suggestions.first { $0.displayText == "ទៅ" })
            engine.acceptSuggestion(continuation)
            XCTAssertEqual(field.text, sentence + "ខ្ញុំចង់ទៅ")
        }
    }

    func testKhmerDoesNotOfferStartersInSecureOrCorrectionDisabledFields() {
        engine.language = .khmer
        target.isSecureTextEntry = true
        engine.configureForField()
        XCTAssertTrue(engine.suggestions.isEmpty)
        target.isSecureTextEntry = false
        target.autocorrectionType = .no
        engine.configureForField()
        XCTAssertTrue(engine.suggestions.isEmpty)
    }

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
        XCTAssertEqual(engine.suggestions.map(\.displayText), ["ខ្ញុំ", "សូម", "តើ"])

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
        target.insertText("កមពុជា")
        engine.textDidChange()
        XCTAssertEqual(engine.suggestions.map(\.displayText), ["“កមពុជា”", "កម្ពុជា"])
        XCTAssertEqual(engine.suggestions.map(\.willAutoReplace), [false, true])

        tap(.space)
        XCTAssertEqual(target.text, "កម្ពុជា")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "កមពុជា")
        tap(.space)
        XCTAssertEqual(target.text, "កមពុជា ")
    }

    func testKhmerCorrectionReadsThroughTransientStaleAndUnavailableContext() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        textTarget.laggingReadsAfterDeleting = 2
        target = textTarget
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        tap(.space)
        XCTAssertEqual(target.text, "ខ្ញុំកម្ពុជា")
        let revert = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(revert.kind, .revert)
        engine.acceptSuggestion(revert)
        XCTAssertEqual(target.text, "ខ្ញុំកមពុជា")
    }

    func testKhmerCorrectionWaitsForTheHostToConfirmTheDeleteBeforeRestoring() async {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        textTarget.laggingReadsAfterDeleting = 6
        textTarget.hidesAfterText = true
        target = textTarget
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "កម្ពុជា")
        tap(.space)
        XCTAssertNotNil(engine.khmerDeleteRecovery)
        await engine.khmerDeleteRecovery?.task.value

        XCTAssertEqual(target.text, "ខ្ញុំកមពុជា ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testBackspaceDuringKhmerRecoveryCanRemoveQueuedInput() async throws {
        let field = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        field.laggingReadsAfterDeleting = 6
        field.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: field)

        tap(.space)
        let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
        tap(.character("ក"))
        tap(.delete)
        tap(.delete)
        await recovery.task.value

        XCTAssertEqual(field.text, "ខ្ញុំកមពុជា")
    }

    func testKhmerRecoveryDoesNotRestoreTextAtAMovedCaretWithHiddenRightContext() async throws {
        let field = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        field.laggingReadsAfterDeleting = 6
        field.hidesAfterText = true
        field.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: field)

        tap(.space)
        let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
        let textAfterHostDelete = field.text
        field.adjustTextPosition(byCharacterOffset: -3)
        engine.selectionDidChange()
        let newCaret = field.cursorIndex
        await recovery.task.value

        XCTAssertEqual(field.text, textAfterHostDelete)
        XCTAssertEqual(field.cursorIndex, newCaret)
    }

    func testKhmerDeleteRecoveryDoesNotWriteAfterTheFieldChanges() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        tap(.space)
        let recovery = try XCTUnwrap(engine.khmerDeleteRecovery)
        target.documentIdentifier = UUID()
        let nextFieldText = target.text

        await recovery.task.value

        XCTAssertEqual(target.text, nextFieldText)
    }

    func testFreshKeyInAnotherFieldIsIndependentOfPendingKhmerDeleteRecovery() async throws {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

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
            let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំកមពុជា")
            textTarget.laggingReadsAfterDeleting = 6
            textTarget.documentIdentifier = UUID()
            textTarget.hidesAfterText = true
            let routedTarget = EmojiRoutedTarget(document: textTarget)
            await loadKhmerKeyboard(for: routedTarget)

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
        await loadKhmerKeyboard(for: target)

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
            await loadKhmerKeyboard(for: field)
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
            await loadKhmerKeyboard(for: field)
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
        await loadKhmerKeyboard(for: field)

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
        await loadKhmerKeyboard(for: field)

        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)

        XCTAssertNil(engine.khmerDeleteRecovery)
        XCTAssertEqual(field.text, String("សាលា".dropLast()) + "។")
    }

    func testKhmerWordDeletionStopsAtTheLatinBoundary() async {
        target = KhmerScalarDeletingTarget(text: "សាលាabc")
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        engine.deleteWordBackward()
        XCTAssertEqual(target.text, "សាលា")
        engine.deleteWordBackward()
        XCTAssertEqual(target.text, "")
    }

    func testKhmerCorrectionUndoStaysInItsOwnDocument() async throws {
        target = FixtureTextTarget(text: "កមពុជា")
        let originalDocument = UUID()
        target.documentIdentifier = originalDocument
        await loadKhmerKeyboard(for: target)

        tap(.space)
        XCTAssertEqual(target.text, "កម្ពុជា")
        let undo = try XCTUnwrap(engine.suggestions.first { $0.kind == .revert })
        target.documentIdentifier = UUID()
        engine.acceptSuggestion(undo)
        XCTAssertEqual(target.text, "កម្ពុជា")
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })

        target.documentIdentifier = originalDocument
        engine.textDidChange()
        engine.acceptSuggestion(try XCTUnwrap(engine.suggestions.first { $0.kind == .revert }))
        XCTAssertEqual(target.text, "កមពុជា")
    }

    func testKhmerCorrectionDoesNotRewriteOrOfferUndoWithoutADocumentIdentifier() async {
        target.insertText("កមពុជា")
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "កមពុជា ")
        XCTAssertNil(engine.khmerDeleteRecovery)
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerWordDeletionLeavesAnIncompleteRunToNormalBackspace() async {
        target = KhmerScalarDeletingTarget(text: "ខ្ញុំស្")
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        let slide = DeleteWordSwipe(engine: engine, touchID: 1, startX: 0)
        XCTAssertTrue(slide.move(to: -engine.layout.letterWidth * 1.2))
        XCTAssertEqual(slide.deletedWordCount, 0)
        XCTAssertEqual(target.text, "ខ្ញុំស្")

        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)
        XCTAssertEqual(target.text, "ខ្ញុំស")
    }

    func testKhmerCorrectionRestoresExactTextWhenHostDeletesAcrossTheBoundary() async {
        target = KhmerOverDeletingTarget(text: "“ កមពុជា")
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "កម្ពុជា")
        tap(.space)
        XCTAssertEqual(target.text, "“ កមពុជា ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerCorrectionRestoresConfirmedDeletesWhenTheHostStopsDeleting() async {
        target = KhmerStopsDeletingTarget(text: "ខ្ញុំកមពុជា")
        target.documentIdentifier = UUID()
        await loadKhmerKeyboard(for: target)

        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "កម្ពុជា")
        tap(.space)
        await engine.khmerDeleteRecovery?.task.value
        XCTAssertEqual(target.text, "ខ្ញុំកមពុជា ")
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
        for letters in [KeyboardLetterLayout.khmer, .khmerism] {
            smartField(language: .khmer)
            target.documentIdentifier = UUID()
            engine.letterLayout = letters
            await engine.khmerAutocompleteLoad?.value
            tap(.character("ច"))
            if letters == .khmer { tap(.shift) }
            tap(.character(letters == .khmer ? "ម" : "ំ"))
            for key in ["ន", "ុ", "ច"] { tap(.character(key)) }
            XCTAssertEqual(target.text, "ចំនុច")
            let suggestion = try XCTUnwrap(engine.suggestions.first { $0.kind == .khmerCorrection(autoReplace: false) })
            XCTAssertEqual(suggestion.displayText, "ចំណុច")
            XCTAssertFalse(suggestion.willAutoReplace)

            tap(.space)
            engine.acceptSuggestion(suggestion)
            XCTAssertEqual(target.text, "ចំនុច ")
            engine.deleteBackward()
            engine.acceptSuggestion(suggestion)
            XCTAssertEqual(target.text, "ចំណុច")
        }
    }

    func testKhmerSpatialSuggestionsRankRealTapsOnBothLayouts() async throws {
        for (letters, neighbor, replacement) in [
            (KeyboardLetterLayout.khmer, "ន", "មាន់"),
            (.khmerism, "ត", "មាត់"),
        ] {
            for (enabled, pick) in [(false, nil), (true, nil), (true, replacement), (true, "ចាប់")] {
                smartField(language: .khmer)
                target.documentIdentifier = UUID()
                engine.letterLayout = letters
                engine.khmerSpatialSuggestions = enabled
                await engine.khmerAutocompleteLoad?.value
                let journalSettings = TypingJournalSettings(defaults: defaults)
                journalSettings.isEnabled = true
                let journal = TypingJournal(directory: nil, settings: journalSettings)
                engine.journal = journal
                if pick != nil {
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
                let words = enabled ? ["“មាប់”", replacement, "ចាប់"] : ["“មាប់”", "ចាប់"]
                XCTAssertEqual(engine.suggestions.map(\.displayText), words)
                XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
                if let pick {
                    let choice = try XCTUnwrap(engine.suggestions.first { $0.replacement == pick })
                    engine.acceptSuggestion(choice)
                    XCTAssertEqual(target.text, pick)
                    tap(.space)
                    if pick == replacement { XCTAssertTrue(journal.current.corrections.isEmpty) }
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

    func testTypingSchoolKeepsTheLiteralPrefixOnSpaceAndPunctuation() async {
        target.documentIdentifier = UUID()
        engine.language = .khmer
        engine.letterLayout = .khmer
        await engine.khmerAutocompleteLoad?.value

        func enterPrefix() {
            for scalar in "សាលារ".unicodeScalars { tap(.character(String(scalar))) }
            XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
        }

        enterPrefix()
        tap(.character("ៀ"))
        tap(.character("ន"))
        tap(.space)
        XCTAssertEqual(target.text, "សាលារៀន ")

        enterPrefix()
        tap(.layerSwitch(.numbers))
        tap(.space)
        XCTAssertEqual(target.text, "សាលារៀន សាលារ ")
        XCTAssertEqual(engine.layout.layer, .letters)

        enterPrefix()
        tap(.character("។"))
        XCTAssertEqual(target.text, "សាលារៀន សាលារ សាលារ។")
    }

    func testKhmerAutocorrectOnPunctuationAndExplicitPick() async throws {
        useKhmerism()
        await engine.khmerAutocompleteLoad?.value
        target.insertText("កមពុជា")
        engine.textDidChange()
        tap(.shift)
        tap(.character("ំ"))
        XCTAssertEqual(target.text, "កម្ពុជា។")

        target.insertText("កមពុជា")
        engine.textDidChange()
        let correction = try XCTUnwrap(engine.suggestions.first(where: \.willAutoReplace))
        engine.acceptSuggestion(correction)
        XCTAssertEqual(target.text, "កម្ពុជា។កម្ពុជា")
    }

    func testKhmerAutocorrectHonorsKeepAndTheAutocorrectSwitch() async throws {
        engine.language = .khmer
        target.documentIdentifier = UUID()
        await engine.khmerAutocompleteLoad?.value
        engine.autocorrect.isEnabled = false
        target.insertText("កមពុជា")
        engine.textDidChange()
        XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
        tap(.space)
        XCTAssertEqual(target.text, "កមពុជា ")

        engine.autocorrect.isEnabled = true
        target.insertText("កមពុជា")
        engine.textDidChange()
        let keep = try XCTUnwrap(engine.suggestions.first)
        XCTAssertEqual(keep.kind, .khmerKeepLiteral)
        engine.acceptSuggestion(keep)
        XCTAssertEqual(target.text, "កមពុជា កមពុជា")
        XCTAssertFalse(engine.suggestions.contains(where: \.willAutoReplace))
        tap(.space)
        XCTAssertEqual(target.text, "កមពុជា កមពុជា ")
    }
}

@MainActor
private final class KhmerDeferredCaretTarget: FixtureTextTarget {
    var delayedProbe: Int?
    var hidesContext = false
    var onDelayedForward: (() -> Void)?
    private(set) var probeMoves: [Int] = []
    private var forwards = 0
    private var stale: (before: String?, after: String?)?

    override var documentContextBeforeInput: String? {
        if let stale { return hidesContext ? nil : stale.before }
        return cursorIndex == 0 ? nil : super.documentContextBeforeInput
    }

    override var documentContextAfterInput: String? {
        if let stale { return hidesContext ? nil : stale.after }
        return super.documentContextAfterInput
    }

    override func adjustTextPosition(byCharacterOffset offset: Int) {
        let previous = (documentContextBeforeInput, documentContextAfterInput)
        super.adjustTextPosition(byCharacterOffset: offset)
        guard let delayedProbe else { return }
        probeMoves.append(offset)
        if offset == 1 { forwards += 1 }
        if forwards == delayedProbe {
            stale = previous
            if offset == 1 { onDelayedForward?() }
            Task { @MainActor in self.stale = nil }
        }
    }
}

@MainActor
private final class KhmerBoundedCaretTarget: FixtureTextTarget {
    var leftWindow = 2
    var ignoresForward = false

    override var documentContextBeforeInput: String? {
        guard let before = super.documentContextBeforeInput, !before.isEmpty else { return nil }
        return String(before.suffix(leftWindow))
    }

    override var documentContextAfterInput: String? { super.documentContextAfterInput.map { String($0.prefix(2)) } }

    override func adjustTextPosition(byCharacterOffset offset: Int) {
        if !ignoresForward || offset <= 0 { super.adjustTextPosition(byCharacterOffset: offset) }
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
    var windowLimit: Int?
    private var echo: String?

    override var documentContextBeforeInput: String? {
        guard let before = super.documentContextBeforeInput else { return nil }
        guard echo != nil || windowLimit != nil else { return before }
        switch reportAfterInsert {
        case .characters: return String(before.suffix(windowLimit ?? echo?.count ?? before.count))
        case .codeUnits:
            let count = windowLimit ?? echo?.utf16.count ?? before.utf16.count
            return String(decoding: before.utf16.suffix(count), as: UTF16.self)
        case .oldPrefix: return echo ?? before
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
        if super.documentContextBeforeInput == "“ ក" {
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
