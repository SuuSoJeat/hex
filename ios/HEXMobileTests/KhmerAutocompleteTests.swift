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

    func testCorrectionsPreserveValidWordsAndJoinedReadings() throws {
        let model = try XCTUnwrap(KhmerAutocomplete.bundled)
        for spelling in ["និង", "នឹង", "កាយរឹទ្ធិ", "រោកសញ្ញា", "សុខសាន្ត", "សួស្តីី"] {
            XCTAssertNil(model.correction(beforeInput: spelling))
        }

        let joinedWords = KhmerAutocomplete(wordlist: "ចំ\t50\nនុច\t15\nចំណុច\t100")
        XCTAssertNil(joinedWords.correction(beforeInput: "ចំនុច"))
        let missingTarget = KhmerAutocomplete(wordlist: "ខ្ញុំ\t100")
        XCTAssertNil(missingTarget.correction(beforeInput: "ចំនុច"))
    }
}
