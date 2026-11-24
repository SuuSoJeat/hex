import XCTest
@testable import HEX

final class KhmerAutocompleteTests: XCTestCase {
    func testLearningDoesNotTreatAmbiguousJoinedWordsAsOneNewWord() {
        let index = KhmerAutocomplete(wordlist: "កា\t10\nកាត\t10\nតង\t10\nង\t10")
        XCTAssertEqual(index.wordsForLearning(in: "កាតង", vocabulary: [], allowsNewWord: true), [])
        XCTAssertEqual(index.wordsForLearning(in: "កា្", vocabulary: [], allowsNewWord: true), [])
    }

    private let model = KhmerAutocomplete(wordlist: """
    ខ្ញុំ\t100
    ស្រ\t90
    ស្រឡាញ់\t70
    ស្រឡាង\t20
    ឡាង\t120
    កម្មករ\t30
    កម្ពុជា\t90
    """)

    func testBundledEnglishSuggestionsIncludeAppNamesAndTechLoanwords() throws {
        let bundled = try XCTUnwrap(KhmerAutocomplete.bundled)
        for (typed, english) in [
            ("អេប៊ីអេ", "ABA Mobile"),
            ("បាគង", "Bakong"),
            ("ហ្គូហ្គលម៉េប", "Google Maps"),
            ("ហ្គូហ្គលម៉ែប", "Google Maps"),
            ("ដោនឡូត", "download"),
            ("ដោនឡូដ", "download"),
        ] {
            XCTAssertEqual(bundled.englishMatch(in: typed, personalWords: [])?.english, english)
        }
    }

    func testAmbiguousEnglishPrefixDoesNotFallBackToAShorterJoinedReading() throws {
        let bundled = try XCTUnwrap(KhmerAutocomplete.bundled)
        for preceding in ["", "ខ្ញុំ"] {
            XCTAssertNil(bundled.englishMatch(in: preceding + "ម៉ៃក្រូ", personalWords: []))
            XCTAssertEqual(bundled.englishMatch(in: preceding + "ក្រូ", personalWords: [])?.english, "Chrome")
        }
    }

    func testEnglishPrefixesUseDistinctTargetsAndPreferAnExactSpelling() {
        let model = KhmerAutocomplete(wordlist: "", englishWordlist: """
        ស្កេន\tscan
        ស្កេនន័រ\tscanner
        វ៉ាយហ្វាយ\tWi-Fi
        វ៉ាយហ្វៃ\tWi-Fi
        """)
        XCTAssertEqual(model.englishMatch(in: "វ", personalWords: [])?.english, "Wi-Fi")
        XCTAssertNil(model.englishMatch(in: "ស", personalWords: []))
        XCTAssertEqual(model.englishMatch(in: "ស្កេន", personalWords: [])?.english, "scan")
    }

    func testEnglishSuggestionsRecoverKnownBoundariesInLongJoinedText() {
        let model = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100\nតេឡេក្រាម\t2", englishWordlist: "តេឡេក្រាម\tTelegram")
        let preceding = String(repeating: "ខ្ញុំ", count: 25)
        for typed in ["តេឡេក្", "តេឡេក្រាម"] {
            let match = model.englishMatch(in: preceding + typed, personalWords: [])
            XCTAssertEqual(match?.typed, typed)
            XCTAssertEqual(match?.english, "Telegram")
            XCTAssertNil(model.englishMatch(in: preceding + "ឝ្ឞ្ស" + typed, personalWords: []))
        }
        XCTAssertNil(model.wordSuffix(in: (preceding + "តេឡេក្រាម")[...]))
    }

    func testEnglishSuggestionsCanFollowAnotherTransliterationInJoinedText() throws {
        let bundled = try XCTUnwrap(KhmerAutocomplete.bundled)
        let choice = bundled.englishMatch(in: "ម៉ៅស៍កុំព្យូ", personalWords: [])
        XCTAssertEqual(choice?.typed, "កុំព្យូ")
        XCTAssertEqual(choice?.english, "computer")

        let model = KhmerAutocomplete(wordlist: "កុំព្យូទ័រ\t1", englishWordlist: """
        ម៉ៅស៍\tmouse
        ម៉ៃក្រូហ្វូន\tmicrophone
        ម៉ៃក្រូសូហ្វ\tMicrosoft
        កុំព្យូទ័រ\tcomputer
        """)
        XCTAssertNil(model.englishMatch(in: "ម៉ៅសកុំព្យូទ័រ", personalWords: []))
        XCTAssertNil(model.englishMatch(in: "ម៉ៃក្រូកុំព្យូទ័រ", personalWords: []))
        XCTAssertNil(model.wordSuffix(in: "ម៉ៅស៍កុំព្យូទ័រ"[...]))
        XCTAssertTrue(model.suggestions(beforeInput: "ម៉ៅស៍កុំព្យូ").isEmpty)
    }

    func testRanksCompletionsAndAppendsTheExactScalarsAfterCoeng() {
        let prefix = "កម្"
        let results = model.suggestions(beforeInput: prefix, limit: 2)
        XCTAssertEqual(results.map(\.word), ["កម្ពុជា", "កម្មករ"])
        XCTAssertEqual(results.map(\.suffix), ["ពុជា", "មករ"])
        for result in results {
            XCTAssertEqual(Array((prefix + result.suffix).unicodeScalars), Array(result.word.unicodeScalars))
        }
        XCTAssertEqual(model.suggestions(beforeInput: prefix, limit: 1), Array(results.prefix(1)))
    }

    func testFirstLetterCompletesAloneAndAfterAJoinedWord() {
        let model = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100\nក\t200\nការ\t10\nក្នុង\t30\nកម្ពុជា\t40\nកើត\t20")
        for prefix in ["ក", "ខ្ញុំក"] {
            let ranked = model.suggestions(beforeInput: prefix)
            XCTAssertEqual(ranked.map(\.word), ["កម្ពុជា", "ក្នុង", "កើត"])
            XCTAssertEqual(ranked.map(\.suffix), ["ម្ពុជា", "្នុង", "ើត"])
            let filtered = model.suggestions(beforeInput: prefix, personalWords: ["ការ"]) { $0 != "កម្ពុជា" }
            XCTAssertEqual(filtered.map(\.word), ["ការ", "ក្នុង", "កើត"])
            XCTAssertNil(model.correction(beforeInput: prefix))
        }
        XCTAssertTrue(model.suggestions(beforeInput: "្").isEmpty)
    }

    func testCompleteWordCanExtendWithoutOfferingItsOwnSpellingOrSplittingIt() {
        let model = KhmerAutocomplete(wordlist: "អរ\t100\nអរគុណ\t50\nអរុណ\t20\nរ\t30\nរក\t80")
        XCTAssertEqual(model.suggestions(beforeInput: "អរ"), [
            .init(word: "អរគុណ", suffix: "គុណ"),
            .init(word: "អរុណ", suffix: "ុណ"),
        ])
        XCTAssertTrue(model.suggestions(beforeInput: "អរ") { _ in false }.isEmpty)
        XCTAssertNil(model.correction(beforeInput: "អរ"))
    }

    func testUsesLongestUnfinishedWordAfterKnownKhmerWords() {
        let results = model.suggestions(beforeInput: "ខ្ញុំស្រឡា")
        XCTAssertEqual(results.map(\.word), ["ស្រឡាញ់", "ស្រឡាង"])
        XCTAssertEqual(results.first?.suffix, "ញ់")
        XCTAssertTrue(model.suggestions(beforeInput: "ខ្ញុំស្រឡាញ់").isEmpty)
        XCTAssertTrue(model.suggestions(beforeInput: "ឝ្ឞ្សស្រឡា").isEmpty)
    }

    @MainActor
    func testPersonalVocabularyCompletesBeforeTheDictionaryEvenWithAutocorrectOff() {
        let autocorrect = AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: nil))
        autocorrect.setLanguage(.khmer)
        autocorrect.setVocabulary(["ហេក្ស", "កម្មករគំរូ"])
        autocorrect.isEnabled = false

        let names = autocorrect.khmerCompletions(using: model, beforeInput: "ខ្ញុំហេ")
        XCTAssertEqual(names, [.init(word: "ហេក្ស", suffix: "ក្ស")])
        let knownName = autocorrect.khmerCompletions(using: model, beforeInput: "ហេក្សស្រឡា")
        XCTAssertEqual(knownName.map(\.word), ["ស្រឡាញ់", "ស្រឡាង"])
        let candidates = autocorrect.khmerCompletions(using: model, beforeInput: "កម្")
        XCTAssertEqual(candidates.map(\.word), ["កម្មករគំរូ", "កម្ពុជា", "កម្មករ"])
    }

    @MainActor
    func testLearnedSpellingsHonorAutocorrectAndKeepChoices() {
        let autocorrect = AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: nil))
        autocorrect.setLanguage(.khmer)
        let typed = "កមពុជា"
        let replacement = "ស្រុកខ្មែរ"
        autocorrect.applyLearning(.init(typos: [typed: replacement]))
        XCTAssertEqual(autocorrect.khmerCorrection(using: model, beforeInput: "ខ្ញុំ" + typed),
                       .init(typed: typed, replacement: replacement))
        XCTAssertNil(autocorrect.khmerCorrection(using: model, beforeInput: "@" + typed))
        autocorrect.isEnabled = false
        XCTAssertNil(autocorrect.khmerCorrection(using: model, beforeInput: typed))
        autocorrect.isEnabled = true
        autocorrect.applyLearning(.init(rejected: [typed]))
        XCTAssertNil(autocorrect.khmerCorrection(using: model, beforeInput: typed))
        autocorrect.applyLearning(.init(typos: [typed: replacement]))
        autocorrect.setVocabulary([typed])
        XCTAssertNil(autocorrect.khmerCorrection(using: model, beforeInput: typed))
    }

    func testFilteredCompletionsLeaveRoomForOtherCandidates() {
        let candidates = model.suggestions(beforeInput: "ស្រឡា", limit: 1) { $0 != "ស្រឡាញ់" }
        XCTAssertEqual(candidates, [.init(word: "ស្រឡាង", suffix: "ង")])
    }

    @MainActor
    func testSwearWordSettingAppliesToKhmerCompletionsAndLearnedFixes() throws {
        let bundled = try XCTUnwrap(KhmerAutocomplete.bundled)
        let autocorrect = AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: nil))
        autocorrect.setLanguage(.khmer)
        let typed = "កមពុជា"
        let swear = "សំផឹង"
        autocorrect.applyLearning(.init(typos: [typed: swear]))

        XCTAssertFalse(autocorrect.khmerCompletions(using: bundled, beforeInput: "សំផឹ").contains { $0.word == swear })
        XCTAssertEqual(autocorrect.khmerCorrection(using: model, beforeInput: typed)?.replacement, "កម្ពុជា")

        autocorrect.allowsSwearing = true
        XCTAssertTrue(autocorrect.khmerCompletions(using: bundled, beforeInput: "សំផឹ").contains { $0.word == swear })
        XCTAssertEqual(autocorrect.khmerCorrection(using: model, beforeInput: typed)?.replacement, swear)

        autocorrect.allowsSwearing = false
        autocorrect.setVocabulary([swear])
        XCTAssertTrue(autocorrect.khmerCompletions(using: bundled, beforeInput: "សំផឹ").contains { $0.word == swear })
    }

    func testRespectsPunctuationAndScriptBoundaries() {
        let original = model.suggestions(beforeInput: "ស្រឡា")
        XCTAssertFalse(original.isEmpty)
        for separator in [" ", "។", "\u{200B}", "ABC", "១"] {
            XCTAssertEqual(model.suggestions(beforeInput: "ឝ្ឞ្ស" + separator + "ស្រឡា"), original)
            XCTAssertTrue(model.suggestions(beforeInput: "ស្រឡា" + separator).isEmpty)
        }
        XCTAssertTrue(KhmerAutocomplete.startsWithWordText("ាអ"))
        XCTAssertTrue(KhmerAutocomplete.startsWithWordText("អ"))
        XCTAssertFalse(KhmerAutocomplete.startsWithWordText("\u{200B}អ"))
        XCTAssertFalse(KhmerAutocomplete.startsWithWordText("។អ"))
    }

    func testNeverSplitsInsideACoengCluster() {
        let model = KhmerAutocomplete(wordlist: """
        ខ្\t20
        ខ\t30
        ញុំ\t40
        """)
        XCTAssertTrue(model.suggestions(beforeInput: "ខ្ញុ").isEmpty)
    }

    func testFindsPrefixInBoundedTrailingContext() {
        let input = String(repeating: "ខ្ញុំ", count: 25) + "ស្រឡា"
        XCTAssertEqual(model.suggestions(beforeInput: input), model.suggestions(beforeInput: "ស្រឡា"))
    }

    func testLoadsBundledWordlist() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        XCTAssertEqual(model.suggestions(beforeInput: "កម្").first?.word, "កម្ពុជា")
        XCTAssertEqual(model.suggestions(beforeInput: "សួស").first?.word, "សួស្តី")
    }

    func testExpandedDictionaryCompletesAndRecognizesTheWholeJoinedWord() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for preceding in ["", "ខ្ញុំ"] {
            let prefix = preceding + "កជ"
            let completion = try XCTUnwrap(model.suggestions(beforeInput: prefix).first { $0.word == "កជើង" })
            let completed = prefix + completion.suffix
            XCTAssertEqual(completed, preceding + "កជើង")
            XCTAssertEqual(model.wordSuffix(in: completed[...]), "កជើង")
        }
    }

    func testSupplementalWordsCompleteAndStayAsTyped() throws {
        let bundled = try XCTUnwrap(KhmerAutocomplete.bundled)
        for word in ["គច្ឆាមិ", "មហាយាន"] {
            let prefix = String(decoding: word.utf16.dropLast(), as: UTF16.self)
            XCTAssertTrue(bundled.suggestions(beforeInput: prefix).contains { $0.word == word })
            XCTAssertNil(bundled.correction(beforeInput: word))
        }

        let model = KhmerAutocomplete(wordlist: "មួយ\t1", supplementalWords: "មហាយាន")
        XCTAssertEqual(model.suggestions(beforeInput: "ម").map(\.word), ["មួយ", "មហាយាន"])
        XCTAssertNil(model.correction(beforeInput: "មហាាយាន"))
    }

    func testCorrectionsUseExactSuffixAfterEstablishedWordBoundaries() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        let correction = KhmerAutocomplete.Correction(typed: "ចំនុច", replacement: "ចំណុច", automaticallyApplies: false)
        for prefix in ["ខ្ញុំ", "ខ្ញុំបានទៅ", "ឝ្ឞ្ស។", "ឝ្ឞ្ស\u{200B}", "Name "] {
            XCTAssertEqual(model.correction(beforeInput: prefix + "ចំនុច"), correction)
        }
        for spelling in ["ឝ្ឞ្សចំនុច", "@ចំនុច", "Nameចំនុច", "ចំនុច្", "ចំនុច។", String(repeating: "ខ្ញុំ", count: 25) + "ចំនុច"] {
            XCTAssertNil(model.correction(beforeInput: spelling))
        }
    }

    func testSchoolPrefixInJoinedTextStaysLiteralAndCanCompleteAPersonalTerm() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for preceding in ["", "ខ្ញុំទៅ"] {
            let prefix = preceding + "សាលារ"
            XCTAssertNil(model.correction(beforeInput: prefix))
            XCTAssertNil(model.correction(beforeInput: prefix + "ៀន"))
            XCTAssertTrue(model.suggestions(beforeInput: prefix, personalWords: ["សាលារៀន"])
                .contains(.init(word: "សាលារៀន", suffix: "ៀន")))
        }
    }

    func testCorrectionsPreserveValidWordsAndJoinedReadings() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for spelling in ["និង", "នឹង", "កាយរឹទ្ធិ", "រោកសញ្ញា", "សុខសាន្ត", "សលា"] {
            XCTAssertNil(model.correction(beforeInput: spelling))
        }

        let joinedWords = KhmerAutocomplete(wordlist: "ចំ\t50\nនុច\t15\nចំណុច\t100")
        XCTAssertNil(joinedWords.correction(beforeInput: "ចំនុច"))
    }

    func testDictionaryCorrectionsRankSingleEditsForAnExplicitPick() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for (typed, replacement) in [("ប្រទសេ", "ប្រទេស"), ("ខ្មរ", "ខ្មែរ"), ("សួស្ដី", "សួស្តី"), ("រង្ស៊ី", "រង្សី")] {
            let expected = KhmerAutocomplete.Correction(typed: typed, replacement: replacement, automaticallyApplies: false)
            XCTAssertEqual(model.correction(beforeInput: typed), expected)
        }

        let oneWord = KhmerAutocomplete(wordlist: "កម្ពុជា\t90")
        XCTAssertEqual(
            oneWord.correction(beforeInput: "កម្ពុកជា"),
            .init(typed: "កម្ពុកជា", replacement: "កម្ពុជា", automaticallyApplies: false)
        )
        XCTAssertEqual(
            oneWord.correction(beforeInput: "កម្ពុសា"),
            .init(typed: "កម្ពុសា", replacement: "កម្ពុជា", automaticallyApplies: false)
        )
    }

    func testSpatialGainRanksAOneScalarSubstitutionWithoutMakingItAutomatic() {
        let model = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100\nចំណាក\t100\nចំណែក\t10")
        let typed = "ចំណោក"
        let input = "ខ្ញុំ" + typed
        let frequent = KhmerAutocomplete.Correction(typed: typed, replacement: "ចំណាក", automaticallyApplies: false)
        let spatial = KhmerAutocomplete.Correction(
            typed: typed, replacement: "ចំណែក", automaticallyApplies: false, rankedByTapPosition: true,
            dictionaryAlternative: "ចំណាក"
        )

        XCTAssertEqual(model.correction(beforeInput: input, substitutionGain: { _, _, _ in nil }), frequent)
        XCTAssertEqual(model.correction(beforeInput: input, substitutionGain: { _, _, _ in 0.64 }), frequent)
        let score: KhmerAutocomplete.SubstitutionGain = { offsetFromEnd, typed, candidate in
            // The vowel ោ is the second scalar from the end, after a complete joined word.
            offsetFromEnd == 1 && typed == 0x17C4 && candidate == 0x17C2 ? 0.65 : nil
        }
        XCTAssertEqual(model.correction(beforeInput: input, substitutionGain: score), spatial)
    }

    func testSpatialGainRespectsSpellingFilters() {
        let model = KhmerAutocomplete(wordlist: "ចំណាក\t100\nចំណែក\t10")
        let typed = "ចំណោក"
        let blocked = "ចំណែក"
        let score: KhmerAutocomplete.SubstitutionGain = { _, _, candidate in
            candidate == 0x17C2 ? 2 : nil
        }

        XCTAssertEqual(
            model.correction(beforeInput: typed, substitutionGain: score, mayOffer: { $0 != blocked }),
            .init(typed: typed, replacement: "ចំណាក", automaticallyApplies: false)
        )
        let spatialOnly = model.correction(beforeInput: typed, substitutionGain: score, mayOffer: { $0 == blocked })
        XCTAssertEqual(spatialOnly?.replacement, blocked)
        XCTAssertNil(spatialOnly?.dictionaryAlternative)
        XCTAssertNil(model.correction(beforeInput: typed, substitutionGain: score, canCorrect: { _ in false }))
    }

    func testSpatialGainPreservesAutomaticRepairsAndKnownWords() {
        let model = KhmerAutocomplete(wordlist: """
        កម្ពុជា\t2000
        សាលា\t100
        """)
        let score: KhmerAutocomplete.SubstitutionGain = { _, _, _ in 2 }

        XCTAssertEqual(
            model.correction(beforeInput: "កមពុជា", substitutionGain: score),
            .init(typed: "កមពុជា", replacement: "កម្ពុជា")
        )
        XCTAssertEqual(
            model.correction(beforeInput: "សាាលា", substitutionGain: score),
            .init(typed: "សាាលា", replacement: "សាលា")
        )
        XCTAssertNil(model.correction(beforeInput: "កម្ពុជា", substitutionGain: score))
        XCTAssertNil(model.correction(beforeInput: "កមពុជា", personalWords: ["កមពុជា"], substitutionGain: score))
    }

    func testDictionaryAutomaticallyRestoresOneMissingCoengInACommonWord() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        let correction = KhmerAutocomplete.Correction(typed: "កមពុជា", replacement: "កម្ពុជា")
        XCTAssertEqual(model.correction(beforeInput: "កមពុជា"), correction)
        XCTAssertEqual(model.correction(beforeInput: "ខ្ញុំកមពុជា"), correction)
    }

    func testMissingCoengNeedsACommonWordWithoutACompetingRepair() {
        let suggestion = KhmerAutocomplete.Correction(typed: "កមពុជា", replacement: "កម្ពុជា", automaticallyApplies: false)
        for wordlist in [
            "កម្ពុជា\t999",
            "កម្ពុជា\t157660\nកមពុជ\t1",
            "កម្ពុជា\t157660\nកម\t100\nរុជា\t1000",
        ] {
            XCTAssertEqual(KhmerAutocomplete(wordlist: wordlist).correction(beforeInput: "កមពុជា"), suggestion)
        }

        let joinedWords = KhmerAutocomplete(wordlist: "កម្ពុជា\t157660\nកម\t100\nពុជា\t100")
        XCTAssertNil(joinedWords.correction(beforeInput: "កមពុជា"))
        let unfinished = KhmerAutocomplete(wordlist: "កម្ពុជា\t157660\nកមពុជារ\t1")
        XCTAssertNil(unfinished.correction(beforeInput: "កមពុជា"))
    }

    func testDictionaryAutomaticallyRepairsAnUnambiguousDoubledVowel() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for (typed, replacement) in [("សាាលា", "សាលា"), ("កម្ពុុជា", "កម្ពុជា"), ("ជាា", "ជា")] {
            XCTAssertEqual(model.correction(beforeInput: typed), .init(typed: typed, replacement: replacement))
        }
        XCTAssertEqual(model.correction(beforeInput: "សួស្តីី"), .init(typed: "ស្តីី", replacement: "ស្តី"))
        XCTAssertEqual(model.correction(beforeInput: "ខ្ញុំបានទៅសាាលា"), .init(typed: "សាាលា", replacement: "សាលា"))
        XCTAssertNil(model.correction(beforeInput: "សាាាលា"))
    }

    func testDictionaryAutomaticallyRepairsADoubledCoengBeforeALetter() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for (typed, replacement) in [("កម្្ពុជា", "កម្ពុជា"), ("ខ្្ញុំ", "ខ្ញុំ")] {
            XCTAssertEqual(model.correction(beforeInput: typed), .init(typed: typed, replacement: replacement))
        }
        XCTAssertNil(model.correction(beforeInput: "ខ្្្ញុំ"))
        XCTAssertNil(model.correction(beforeInput: "ខ្្"))
    }

    func testDictionaryPreservesUnfinishedPrefixesAndMixedScriptIdentifiers() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for spelling in ["កម្", "កម្ពុជ", "កមពុជា្", "កមពុជា។", "កម្ពុ\u{200C}ជា", "Nameកមពុជា", "@សាាលា", "ឝ្ឞ្សកមពុជា"] {
            XCTAssertNil(model.correction(beforeInput: spelling))
        }
    }
}
