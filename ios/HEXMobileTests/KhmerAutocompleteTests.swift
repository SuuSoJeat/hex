import XCTest
@testable import HEX

final class KhmerAutocompleteTests: XCTestCase {
    private let model = KhmerAutocomplete(wordlist: """
    ខ្ញុំ\t100
    ស្រ\t90
    ស្រឡាញ់\t70
    ស្រឡាង\t20
    ឡាង\t120
    កម្មករ\t30
    កម្ពុជា\t90
    """)

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

    func testBundledWordlistSupportsEachReviewedSpellingCorrection() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        let spellings = [
            ("ចំនុច", "ចំណុច"),
            ("សមាគុមន៍", "សមាគម"),
            ("ទន់ភ្លុន", "ទន់ភ្លន់"),
            ("កូមារភាព", "កុមារភាព"),
            ("បុំផ្ទុះ", "បំផ្ទុះ"),
            ("សមត្ថិភាព", "សមត្ថភាព"),
        ]
        for (typed, replacement) in spellings {
            XCTAssertEqual(model.correction(beforeInput: typed), .init(typed: typed, replacement: replacement))
            XCTAssertNil(model.correction(beforeInput: replacement))
        }
    }

    func testCorrectionsUseExactSuffixAfterEstablishedWordBoundaries() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        let correction = KhmerAutocomplete.Correction(typed: "ចំនុច", replacement: "ចំណុច")
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
        let missingTarget = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100")
        XCTAssertNil(missingTarget.correction(beforeInput: "ចំនុច"))
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
            typed: typed, replacement: "ចំណែក", automaticallyApplies: false, rankedByTapPosition: true
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
        XCTAssertNil(model.correction(beforeInput: typed, substitutionGain: score, canCorrect: { _ in false }))
    }

    func testSpatialGainPreservesAutomaticRepairsAndKnownWords() {
        let model = KhmerAutocomplete(wordlist: """
        ចំណុច\t100
        ចំសុច\t1000
        កម្ពុជា\t2000
        សាលា\t100
        """)
        let score: KhmerAutocomplete.SubstitutionGain = { _, _, _ in 2 }

        XCTAssertEqual(
            model.correction(beforeInput: "ចំនុច", substitutionGain: score),
            .init(typed: "ចំនុច", replacement: "ចំណុច")
        )
        XCTAssertEqual(
            model.correction(beforeInput: "កមពុជា", substitutionGain: score),
            .init(typed: "កមពុជា", replacement: "កម្ពុជា")
        )
        XCTAssertEqual(
            model.correction(beforeInput: "សាាលា", substitutionGain: score),
            .init(typed: "សាាលា", replacement: "សាលា")
        )
        XCTAssertNil(model.correction(beforeInput: "ចំណុច", substitutionGain: score))
        XCTAssertNil(model.correction(beforeInput: "ចំនុច", personalWords: ["ចំនុច"], substitutionGain: score))
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
