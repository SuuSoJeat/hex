import UIKit
import XCTest
@testable import HEX

@MainActor
final class FullKeyboardEngineTests: XCTestCase {
    var target: FixtureTextTarget!

    var engine: FullKeyboardEngine!

    var now: TimeInterval = 100

    var suiteName: String!

    var defaults: UserDefaults!

    /// The layouts are Apple's iOS 27 keyboard; CI's newest simulator runtime is iOS 26.5, so the
    /// version these tests describe is pinned (the before-27 Ukrainian test sets 26 itself).
    var runningSystemMajorVersion = 0

    override func setUp() async throws {
        runningSystemMajorVersion = KeyboardLanguage.systemMajorVersion
        KeyboardLanguage.systemMajorVersion = 27
        suiteName = "FullKeyboardEngineTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        target = FixtureTextTarget()
        target.autocapitalizationType = UITextAutocapitalizationType.none
        let ac = AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults))
        engine = FullKeyboardEngine(target: target, autocorrect: ac)
        engine.width = 393
        engine.clock = { [unowned self] in self.now }
        engine.configureForField()
    }

    override func tearDown() async throws {
        KeyboardLanguage.systemMajorVersion = runningSystemMajorVersion
        defaults.removePersistentDomain(forName: suiteName)
    }

    func point(_ kind: KeyKind) -> CGPoint {
        let key = engine.layout.key(kind)!
        return CGPoint(x: key.frame.midX, y: key.frame.midY)
    }

    func down(_ id: Int, _ kind: KeyKind) { engine.touchBegan(id: id, at: point(kind)) }

    func up(_ id: Int, _ kind: KeyKind) { engine.touchEnded(id: id, at: point(kind)) }

    func tap(_ kind: KeyKind) {
        let at = point(kind)
        engine.touchBegan(id: 1, at: at)
        engine.touchEnded(id: 1, at: at)
    }

    func type(_ text: String) {
        for ch in text {
            tap(ch == " " ? .space : .character(String(ch)))
            now += 0.5
        }
    }

    func tapAt(_ point: CGPoint, id: Int = 1) {
        engine.touchBegan(id: id, at: point)
        engine.touchEnded(id: id, at: point)
        now += 0.5
    }

    func suggestion(_ text: String, _ kind: KeyboardSuggestion.Kind = .secondary) -> KeyboardSuggestion {
        KeyboardSuggestion(displayText: kind == .keepLiteral ? "“\(text)”" : text, replacement: text, kind: kind)
    }

    /// "brown" in "the quick brown fox" selected and typed over: the cursor sits between the
    /// space before it and the space after it.
    func typeOverBrown() {
        type("the quick  fox")
        target.adjustTextPosition(byCharacterOffset: -4)
        engine.textDidChange()
    }

    func swipeEngine(_ text: String) -> (FixtureTextTarget, FullKeyboardEngine) {
        let field = FixtureTextTarget(text: text)
        field.autocapitalizationType = UITextAutocapitalizationType.none
        let keys = FullKeyboardEngine(
            target: field,
            autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults))
        )
        keys.width = 393
        keys.configureForField()
        return (field, keys)
    }

    func deleteSample(_ keys: FullKeyboardEngine, dx: CGFloat = 0) -> TypingLogTouchSample {
        let key = keys.layout.key(.delete)!
        return TypingLogTouchSample(point: CGPoint(x: key.frame.midX + dx, y: key.frame.midY), timestamp: 0)
    }

    /// Types a mark from the 123 page; the next space goes back to the letters.
    func punctuate(_ mark: String) {
        if engine.layout.layer == .letters { tap(.layerSwitch(.numbers)) }
        tap(.character(mark))
        now += 0.5
    }

    /// Types `text` key by key: letters on the letters page, digits and marks from the 123 page.
    func keys(_ text: String) {
        for ch in text {
            if ch == " " {
                tap(.space)
            } else if ch.isLetter {
                if engine.layout.layer != .letters { tap(.layerSwitch(.letters)) }
                tap(.character(String(ch)))
            } else {
                if engine.layout.layer == .letters { tap(.layerSwitch(.numbers)) }
                tap(.character(String(ch)))
            }
            now += 0.5
        }
    }

    func smartField(quotes: UITextSmartQuotesType? = .default, dashes: UITextSmartDashesType? = .default, language: KeyboardLanguage = .english) {
        target = FixtureTextTarget()
        target.autocapitalizationType = UITextAutocapitalizationType.none
        target.smartQuotesType = quotes
        target.smartDashesType = dashes
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.width = 393
        engine.clock = { [unowned self] in self.now }
        engine.language = language
        engine.configureForField()
    }

    /// A 390 pt keyboard with Swipe typing on: its key plane, typing into a field holding
    /// `text` (or the given one, for a host that does something particular).
    func swipeKeyboard(
        _ text: String = "", language: KeyboardLanguage = .english, target: FixtureTextTarget? = nil,
        letters: KeyboardLetterLayout? = nil
    ) throws -> (FixtureTextTarget, KeyboardKeyPlaneView) {
        let field = target ?? FixtureTextTarget(text: text)
        field.autocapitalizationType = UITextAutocapitalizationType.none
        let keys = FullKeyboardEngine(
            target: field,
            autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults))
        )
        keys.width = 390
        keys.language = language
        keys.letterLayout = letters
        keys.configureForField()
        let plane = KeyboardKeyPlaneView(engine: keys)
        plane.swipe = SwipeTyping(engine: keys, model: try XCTUnwrap(TypingDecoderModel.bundled(language.rawValue)))
        return (field, plane)
    }

    func sample(_ point: CGPoint) -> TypingLogTouchSample {
        TypingLogTouchSample(point: point, timestamp: 0)
    }

    /// Swipes `word` through its keys' centres; `lift` false leaves the finger down.
    func swipe(_ word: String, on plane: KeyboardKeyPlaneView, id: Int = 50, lift: Bool = true) {
        swipe(points: SwipePath.through(word, keys: plane.engine.swipeKeys), on: plane, id: id, lift: lift)
    }

    func swipe(points: [CGPoint], on plane: KeyboardKeyPlaneView, id: Int = 50, lift: Bool = true) {
        plane.began(id: id, sample: sample(points[0]))
        for point in points.dropFirst() {
            plane.moved(id: id, sample: sample(point))
        }
        if lift { plane.ended(id: id, sample: sample(points[points.count - 1])) }
    }

    func tap(_ kind: KeyKind, on plane: KeyboardKeyPlaneView, id: Int = 60) {
        let key = plane.engine.layout.key(kind)!
        let centre = CGPoint(x: key.frame.midX, y: key.frame.midY)
        plane.began(id: id, sample: sample(centre))
        plane.ended(id: id, sample: sample(centre))
    }

    func testRolloverKeepsOrder() {
        down(1, .character("t"))
        down(2, .character("h"))
        up(1, .character("t"))
        up(2, .character("h"))
        XCTAssertEqual(target.text, "th")
    }

    func testRolloverWhenTheSecondKeyLiftsFirst() {
        down(1, .character("t"))
        down(2, .character("h"))
        up(2, .character("h"))
        up(1, .character("t"))
        XCTAssertEqual(target.text, "th")
    }

    /// Space in a rollover keeps its place: a letter held as space goes down goes in first, and
    /// space goes in when the next letter goes down, even if that letter lifts first. It used
    /// to wait for its own lift, so "a b" typed fast came out "ab ".
    func testRolloverWithTheSpaceBarKeepsOrder() {
        down(1, .character("a"))
        down(2, .space)
        up(1, .character("a"))
        down(3, .character("b"))
        up(3, .character("b"))
        up(2, .space)
        XCTAssertEqual(target.text, "a b")

        down(4, .space)
        down(5, .character("c"))
        engine.holdSpace(forTouch: 4)
        XCTAssertFalse(engine.isTrackpadActive, "a space already typed doesn't become the trackpad")
        up(4, .space)
        up(5, .character("c"))
        XCTAssertEqual(target.text, "a b c")
    }

    func testSlidingToAnotherKeyTypesWhereTheFingerLifts() {
        down(1, .character("f"))
        engine.touchMoved(id: 1, to: point(.character("g")))
        XCTAssertEqual(engine.previewKey?.kind, .character("g"))
        up(1, .character("g"))
        XCTAssertEqual(target.text, "g")
    }

    func testShiftChordAndOneShot() {
        down(1, .shift)
        down(2, .character("a"))
        up(2, .character("a"))
        down(3, .character("b"))
        up(3, .character("b"))
        up(1, .shift)
        tap(.character("c"))
        XCTAssertEqual(target.text, "ABc")

        tap(.shift)
        tap(.character("d"))
        tap(.character("e"))
        XCTAssertEqual(target.text, "ABcDe")
    }

    private func useKhmerism() {
        engine.language = .khmer
        engine.letterLayout = .khmerism
    }

    func testKhmerismShiftTypesOneCharacter() throws {
        target.autocapitalizationType = .sentences
        useKhmerism()
        engine.configureForField()
        let key = try XCTUnwrap(engine.layout.key(.character("ហ")))
        XCTAssertEqual(engine.displayLabel(for: key), "ហ")
        tap(.shift)
        XCTAssertEqual(engine.displayLabel(for: key), "១")
        tap(key.kind)
        XCTAssertEqual(engine.shift.state, .off)
        XCTAssertEqual(engine.displayLabel(for: key), "ហ")
        tap(.space)
        engine.textDidChange()
        tap(key.kind)
        XCTAssertEqual(target.text, "១ ហ")
    }

    func testStandardKhmerShiftAndSmartModeUseTheSameTypingRules() {
        for smartMode in [false, true] {
            smartField(language: .khmer)
            engine.letterLayout = .khmer
            engine.khmerismSmartMode = smartMode
            tap(.shift)
            tap(.character("្")) // ញ
            now += 0.5
            tap(.shift)
            tap(.character("ម")) // ំ
            XCTAssertEqual(target.text, smartMode ? "ខ្ញុំ" : "ញំ")
            XCTAssertEqual(engine.shift.state, .off)
        }
    }

    func testStandardKhmerKeepsKeysInPlaceAfterCoengAndAdaptsItsDiacriticWithSmartMode() throws {
        engine.language = .khmer
        engine.letterLayout = .khmer
        let vowel = try XCTUnwrap(engine.layout.key(.character("ោ")))
        let sign = try XCTUnwrap(engine.layout.key(.character("៊")))
        tap(.character("ស"))
        tap(.character("្"))
        XCTAssertTrue(engine.isAfterKhmerCoeng)
        XCTAssertEqual(engine.displayLabel(for: vowel), "ោ")
        tap(.character("ថ"))
        XCTAssertEqual(target.text, "ស្ថ")

        engine.khmerismSmartMode = true
        tap(.character("ក"))
        XCTAssertEqual(engine.displayLabel(for: sign), "៏")
        tap(sign.kind)
        XCTAssertEqual(target.text, "ស្ថក៏")
    }

    func testKhmerismSmartModeExpandsIInJoinedText() {
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ប"))
        tap(.character("ា"))
        tap(.character("ន"))
        tap(.character("ញ"))
        XCTAssertEqual(target.text, "បានញ")
        tap(.character("ំ"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("បានខ្ញុំ".unicodeScalars))
    }

    func testKhmerSmartModeKeepsLiteralKeysInFieldsThatDisableWordCorrections() {
        for (keyboardType, contentType, autocorrection) in [
            (UIKeyboardType.emailAddress, nil, UITextAutocorrectionType.default),
            (.default, UITextContentType.username, .default),
            (.default, nil, .no),
        ] {
            smartField(language: .khmer)
            target.keyboardType = keyboardType
            target.textContentType = contentType
            target.autocorrectionType = autocorrection
            engine.configureForField()
            engine.khmerismSmartMode = true
            tap(.shift)
            tap(.character("្")) // ញ
            tap(.shift)
            tap(.character("ម")) // ំ
            XCTAssertEqual(target.text, "ញំ")
        }
    }

    func testKhmerismSmartModeDefaultsToLiteralTyping() {
        useKhmerism()

        tap(.character("ញ"))
        tap(.character("ំ"))
        tap(.character("ស"))
        tap(.character("៉"))
        tap(.character("ា"))
        tap(.character("ា"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ញំស៉ាា".unicodeScalars))
    }

    func testKhmerismSmartModePreservesSubscriptNyo() {
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ក"))
        tap(.character("្"))
        tap(.character("ញ"))
        tap(.character("ំ"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ក្ញំ".unicodeScalars))
    }

    func testKhmerismSmartModeDoesNotRewriteNyoAfterCaretMovement() {
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ញ"))
        target.adjustTextPosition(byCharacterOffset: -1)
        engine.selectionDidChange()
        target.adjustTextPosition(byCharacterOffset: 1)
        engine.selectionDidChange()
        tap(.character("ំ"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ញំ".unicodeScalars))
    }

    func testKhmerismSmartModeDoesNotRewriteExistingNyo() {
        target.insertText("ញ")
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ំ"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ញំ".unicodeScalars))
    }

    func testKhmerismSmartModeKeepsLiteralKeysAtAnUnverifiableLeftEdge() {
        target = KhmerNilBeforeStartTarget(text: "បាន")
        target.adjustTextPosition(byCharacterOffset: -target.text.count)
        engine = FullKeyboardEngine(target: target)
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ញ"))
        tap(.character("ំ"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ញំបាន".unicodeScalars))
    }

    func testKhmerismSmartModeUpdatesDiacriticKeyFollowingAConsonant() throws {
        let pairs = [("ក", "៏"), ("ដ", "៏"), ("ន", "៍"), ("ស", "៊"), ("ហ", "៊"), ("អ", "៊"), ("ប", "៉")]
        for (consonant, sign) in pairs {
            smartField(language: .khmer)
            engine.letterLayout = .khmerism
            engine.khmerismSmartMode = true
            let diacritic = KeyKind.character("៉")
            let key = try XCTUnwrap(engine.layout.key(diacritic))

            tap(.character(consonant))
            XCTAssertEqual(engine.keycapLabel(for: key), sign, consonant)
            down(10, diacritic)
            XCTAssertEqual(engine.keyPreview?.label, sign, consonant)
            up(10, diacritic)

            XCTAssertEqual(Array(target.text.unicodeScalars), Array((consonant + sign).unicodeScalars))
            XCTAssertEqual(engine.keycapLabel(for: key), "៉")
        }
    }

    func testKhmerismSmartModeUsesLastExplicitDiacritic() {
        useKhmerism()
        engine.khmerismSmartMode = true
        let diacritic = KeyKind.character("៉")

        tap(.character("ប"))
        tap(diacritic)
        XCTAssertEqual(target.text, "ប៉")
        down(10, diacritic)
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
        up(10, diacritic)
        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ប៊".unicodeScalars))

        tap(.character("ន"))
        tap(diacritic)
        XCTAssertEqual(target.text, "ប៊ន៍")
        let asda = KeyKind.character("ៃ")
        down(11, asda)
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 11))
        up(11, asda)
        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ប៊ន៏".unicodeScalars))
    }

    func testKhmerismSmartModeCombinesQuickRepeatedVowels() {
        let pairs = [("ា", "ាំ"), ("េ", "េះ"), ("ោ", "ោះ")]
        for (vowel, combined) in pairs {
            smartField(language: .khmer)
            engine.letterLayout = .khmerism
            engine.khmerismSmartMode = true
            tap(.character("ក"))
            tap(.character(vowel))
            now += 0.1
            tap(.character(vowel))

            XCTAssertEqual(Array(target.text.unicodeScalars), Array(("ក" + combined).unicodeScalars))
        }
    }

    func testKhmerismSmartModeLeavesSlowRepeatedVowelsLiteral() {
        useKhmerism()
        engine.khmerismSmartMode = true

        tap(.character("ក"))
        tap(.character("ា"))
        now += 0.75
        tap(.character("ា"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("កាា".unicodeScalars))
    }

    func testKhmerismSmartModeOrdersAnExplicitShifterBeforeTheVowel() {
        for field in [FixtureTextTarget(), KhmerScalarDeletingTarget()] {
            target = field
            engine = FullKeyboardEngine(target: field)
            useKhmerism()
            engine.khmerismSmartMode = true
            tap(.character("ម"))
            tap(.character("ក"))
            tap(.character("ា"))
            tap(.shift)
            let diacritic = KeyKind.character("៉")
            down(10, diacritic)
            XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
            up(10, diacritic)

            XCTAssertEqual(Array(field.text.unicodeScalars), Array("មក៉ា".unicodeScalars))
        }
    }

    func testKhmerismSmartModeOrdersAnExplicitShifterBeforeTheSubscript() {
        useKhmerism()
        engine.khmerismSmartMode = true
        tap(.character("ស"))
        tap(.character("្"))
        tap(.character("រ"))
        tap(.shift)
        tap(.character("៉"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("ស៊្រ".unicodeScalars))
    }

    func testKhmerismSmartModeOrdersALateVowelBeforeTheFinalSign() {
        useKhmerism()
        engine.khmerismSmartMode = true
        tap(.character("ក"))
        tap(.character("ំ"))
        tap(.character("ា"))

        XCTAssertEqual(Array(target.text.unicodeScalars), Array("កាំ".unicodeScalars))
    }

    func testKhmerismDoubleTapLocksShiftUntilTappedAgain() {
        useKhmerism()
        let key = KeyKind.character("ហ")
        tap(.shift)
        now += 0.1
        tap(.shift)
        XCTAssertEqual(engine.shift.state, .locked)
        tap(key)
        tap(key)
        XCTAssertEqual(target.text, "១១")
        XCTAssertEqual(engine.shift.state, .locked)
        down(10, key)
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
        up(10, key)
        XCTAssertEqual(engine.shift.state, .locked)

        tap(.shift)
        tap(key)
        XCTAssertEqual(target.text, "១១ហហ")

        tap(.shift)
        tap(.layerSwitch(.numbers))
        tap(.layerSwitch(.letters))
        XCTAssertEqual(engine.shift.state, .off)
    }

    func testKhmerismHoldShiftAndSlideTypesOneShiftedCharacter() throws {
        useKhmerism()
        let key = try XCTUnwrap(engine.layout.key(.character("ហ")))
        down(10, .shift)
        XCTAssertEqual(engine.keycapLabel(for: key), "ហ")
        XCTAssertEqual(engine.khmerismAlternate(for: key, onKeycap: true), "១")
        engine.touchMoved(id: 10, to: point(key.kind))
        XCTAssertEqual(engine.keyPreview?.label, "១")
        up(10, key.kind)
        XCTAssertEqual(engine.shift.state, .off)
        tap(key.kind)
        XCTAssertEqual(target.text, "១ហ")
    }

    func testKhmerismCancellingHeldShiftAfterTypingReleasesTheChord() {
        useKhmerism()
        let key = KeyKind.character("ហ")
        down(10, .shift)
        tap(key)
        engine.touchCancelled(id: 10)
        XCTAssertFalse(engine.shift.isHeld)
        tap(key)
        XCTAssertEqual(target.text, "១ហ")
    }

    func testCancellingHeldEnglishShiftReleasesTheChord() {
        let key = KeyKind.character("a")
        down(10, .shift)
        tap(key)
        engine.touchCancelled(id: 10)
        XCTAssertFalse(engine.shift.isHeld)
        tap(key)
        XCTAssertEqual(target.text, "Aa")
    }

    func testKhmerismCornerHoldTypesOnceAndPreservesUnicodeScalars() throws {
        useKhmerism()
        tap(.character("ក"))
        let coeng = KeyKind.character("\u{17D2}")
        let key = try XCTUnwrap(engine.layout.key(coeng))
        XCTAssertEqual(engine.displayLabel(for: key), "\u{17D2}")
        tap(coeng)
        tap(.character("រ"))
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x179A])

        let start = point(.character("ក"))
        engine.touchBegan(id: 10, at: start)
        XCTAssertEqual(engine.keyPreview?.label, "ក")
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
        XCTAssertEqual(engine.keyPreview?.key.kind, .character("ក"))
        XCTAssertEqual(engine.keyPreview?.label, "៩")
        XCTAssertFalse(engine.handleCharacterHold(forTouch: 10))
        engine.touchEnded(id: 10, at: start)
        XCTAssertNil(engine.keyPreview)
        XCTAssertEqual(target.text, "ក្រ៩")
        XCTAssertNil(engine.activeAccentMenu)

        tap(.shift)
        engine.touchBegan(id: 11, at: start)
        XCTAssertEqual(engine.keyPreview?.label, "៩")
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 11))
        XCTAssertEqual(engine.keyPreview?.label, "ក")
        XCTAssertEqual(engine.shift.state, .off)
        engine.touchEnded(id: 11, at: start)
        XCTAssertEqual(target.text, "ក្រ៩ក")
    }

    func testKhmerismCoengPromotesConsonantsWithoutChangingTouchTargets() throws {
        useKhmerism()
        let coeng = KeyKind.character("\u{17D2}")
        let vowel = KeyKind.character("ោ")
        let baseKeys = engine.layout.keys
        let promoted = [
            ("ោ", "ថ"), ("ែ", "ធ"), ("ិ", "ខ"), ("ី", "ឃ"),
            ("េ", "ឡ"), ("្", "ផ"), ("ា", "ភ"), ("ះ", "ឆ"), ("ៗ", "ឈ"),
            ("ុ", "ឋ"), ("ូ", "ឍ"),
        ]
        tap(.character("ក"))
        tap(coeng)

        XCTAssertEqual(engine.layout.keys.map(\.kind), baseKeys.map(\.kind))
        XCTAssertEqual(engine.layout.keys.map(\.frame), baseKeys.map(\.frame))
        XCTAssertEqual(engine.layout.keys.map(\.hitFrame), baseKeys.map(\.hitFrame))
        for (base, consonant) in promoted {
            let key = try XCTUnwrap(engine.layout.key(.character(base)))
            XCTAssertEqual(engine.keycapLabel(for: key), consonant)
            XCTAssertEqual(engine.displayLabel(for: key), consonant)
        }
        XCTAssertTrue(engine.layout.keys.allSatisfy { engine.khmerismAlternate(for: $0, onKeycap: true) == nil })
        XCTAssertEqual(engine.keyKind(at: point(vowel)), vowel)
        down(10, vowel)
        XCTAssertEqual(engine.keyPreview?.key.kind, vowel)
        XCTAssertEqual(engine.keyPreview?.label, "ថ")
        up(10, vowel)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x1790])
        let vowelKey = try XCTUnwrap(engine.layout.key(vowel))
        XCTAssertEqual(engine.keycapLabel(for: vowelKey), "ោ")
        XCTAssertEqual(engine.khmerismAlternate(for: vowelKey, onKeycap: true), "ថ")

        tap(coeng)
        tap(coeng)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x1790, 0x17D2, 0x1795])
        let coengKey = try XCTUnwrap(engine.layout.key(coeng))
        XCTAssertEqual(engine.keycapLabel(for: coengKey), "\u{17D2}")
    }

    func testKhmerismCoengHoldTypesTheOriginalKeyOrExistingAlternate() throws {
        useKhmerism()
        let coeng = KeyKind.character("\u{17D2}")
        let vowel = KeyKind.character("ោ")
        let consonant = KeyKind.character("ហ")

        tap(.character("ក"))
        tap(coeng)
        down(10, vowel)
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
        XCTAssertEqual(engine.keyPreview?.label, "ោ")
        up(10, vowel)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x17C4])

        tap(coeng)
        let key = try XCTUnwrap(engine.layout.key(consonant))
        XCTAssertEqual(engine.keycapLabel(for: key), "ហ")
        down(11, consonant)
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 11))
        XCTAssertEqual(engine.keyPreview?.label, "១")
        up(11, consonant)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x17C4, 0x17D2, 0x17E1])
    }

    func testKhmerismCoengGivesManualShiftAndCapsLockPrecedence() throws {
        useKhmerism()
        let coeng = KeyKind.character("\u{17D2}")
        let digit = try XCTUnwrap(engine.layout.key(.character("ហ")))
        let vowel = try XCTUnwrap(engine.layout.key(.character("ោ")))
        tap(.character("ក"))
        tap(coeng)
        XCTAssertEqual(engine.keycapLabel(for: digit), "ហ")
        tap(.shift)
        XCTAssertEqual(engine.keycapLabel(for: digit), "១")
        XCTAssertEqual(engine.khmerismAlternate(for: digit, onKeycap: true), "ហ")
        tap(digit.kind)
        XCTAssertEqual(engine.shift.state, .off)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x17E1])

        tap(coeng)
        now += 0.5
        tap(.shift)
        now += 0.1
        tap(.shift)
        XCTAssertEqual(engine.shift.state, .locked)
        XCTAssertEqual(engine.keycapLabel(for: digit), "១")
        tap(.shift)
        XCTAssertEqual(engine.shift.state, .off)
        XCTAssertEqual(engine.keycapLabel(for: digit), "ហ")
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")
        XCTAssertNil(engine.khmerismAlternate(for: vowel, onKeycap: true))
    }

    func testKhmerismCoengFollowsBackspaceCaretAndExternalText() throws {
        target = KhmerScalarDeletingTarget()
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        useKhmerism()
        let coeng = KeyKind.character("\u{17D2}")
        let vowel = try XCTUnwrap(engine.layout.key(.character("ោ")))

        tap(.character("ក"))
        tap(coeng)
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")
        tap(.delete)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780])
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")

        target.insertText("\u{17D2} រ")
        target.adjustTextPosition(byCharacterOffset: 0)
        engine.textDidChange()
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")
        target.adjustTextPosition(byCharacterOffset: -2)
        engine.selectionDidChange()
        XCTAssertEqual(target.documentContextBeforeInput, "ក\u{17D2}")
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")
        target.deleteBackward()
        target.insertText("រ")
        engine.textDidChange()
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x179A, 0x20, 0x179A])
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")
    }

    func testKhmerismCoengRolloverRemapsTheNextKeyInALaggingField() {
        target = LaggingField()
        target.autocorrectionType = .no
        engine = FullKeyboardEngine(target: target)
        useKhmerism()
        let coeng = KeyKind.character("្")
        let vowel = KeyKind.character("ោ")

        tap(.character("ក"))
        down(10, coeng)
        down(11, vowel)
        XCTAssertEqual(target.documentContextBeforeInput, "ក")
        XCTAssertEqual(engine.keyPreview?.label, "ថ")
        up(11, vowel)
        up(10, coeng)
        XCTAssertEqual(target.text.unicodeScalars.map(\.value), [0x1780, 0x17D2, 0x1790])
        XCTAssertEqual(engine.displayLabel(for: engine.layout.key(vowel)!), "ោ")
    }

    func testKhmerismCoengDropsWhenSelectionOrDocumentChanges() throws {
        target = LaggingField()
        target.documentIdentifier = UUID()
        engine = FullKeyboardEngine(target: target)
        useKhmerism()
        let vowel = try XCTUnwrap(engine.layout.key(.character("ោ")))

        tap(.character("ក"))
        tap(.character("្"))
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")
        target.selectedText = "ក"
        engine.selectionDidChange()
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")
        target.selectedText = nil
        engine.selectionDidChange()
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")

        target.documentIdentifier = UUID()
        engine.textDidChange()
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")
    }

    func testKhmerismCoengRedrawsWhenAFieldChangeClearsItWithoutSuggestions() throws {
        useKhmerism()
        target.autocorrectionType = .no
        tap(.character("ក"))
        tap(.character("្"))
        let vowel = try XCTUnwrap(engine.layout.key(.character("ោ")))
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ថ")
        XCTAssertTrue(engine.suggestions.isEmpty)

        var redrew = false
        engine.onChange = { redrew = true }
        target.adjustTextPosition(byCharacterOffset: -target.cursorIndex)
        engine.configureForField()
        XCTAssertEqual(engine.keycapLabel(for: vowel), "ោ")
        XCTAssertTrue(redrew)
    }

    func testKhmerismMovingOutOfHoldRangeStillAllowsATap() {
        useKhmerism()
        let start = point(.character("ក"))
        let above = CGPoint(x: start.x, y: start.y - FullKeyboardEngine.accentSlop - 1)
        engine.touchBegan(id: 10, at: start)
        engine.touchMoved(id: 10, to: above)
        XCTAssertFalse(engine.handleCharacterHold(forTouch: 10))
        engine.touchEnded(id: 10, at: start)
        XCTAssertEqual(target.text, "ក")

        engine.touchBegan(id: 11, at: start)
        engine.touchCancelled(id: 11)
        XCTAssertFalse(engine.handleCharacterHold(forTouch: 11))
        XCTAssertEqual(target.text, "ក")
    }

    func testKhmerismCharacterSlidesRetargetLettersAndNumbers() {
        useKhmerism()
        let next = KeyKind.character("ច")
        down(10, .character("ក"))
        engine.touchMoved(id: 10, to: point(next))
        XCTAssertEqual(engine.keyPreview?.label, "ច")
        XCTAssertTrue(engine.handleCharacterHold(forTouch: 10))
        up(10, next)
        XCTAssertEqual(target.text, "០")

        tap(.layerSwitch(.numbers))
        down(11, .character("1"))
        engine.touchMoved(id: 11, to: point(.character("2")))
        up(11, .character("2"))
        XCTAssertEqual(target.text, "០2")
    }

    func testKhmerismPlaneHoldTimerTypesTheCornerCharacter() {
        useKhmerism()
        let plane = KeyboardKeyPlaneView(engine: engine)
        let sample = TypingLogTouchSample(point: point(.character("ហ")), timestamp: 0)
        plane.began(id: 1, sample: sample)
        RunLoop.main.run(until: Date().addingTimeInterval(FullKeyboardEngine.accentHoldDelay + 0.15))
        XCTAssertEqual(target.text, "១")
        XCTAssertEqual(engine.keyPreview?.label, "១")
        plane.ended(id: 1, sample: sample)
        XCTAssertEqual(target.text, "១")
        XCTAssertNil(engine.keyPreview)
    }

    func testKhmerismEnglishNumberRowsAndKhmerSymbolHolds() {
        useKhmerism()
        tap(.layerSwitch(.numbers))
        tap(.character("0"))
        XCTAssertEqual(engine.layout.key(.layerSwitch(.letters))?.label, "កខគ")
        tap(.space)
        XCTAssertEqual(engine.layout.layer, .letters)
        tap(.space)
        XCTAssertEqual(target.text, "0។ ")
        tap(.layerSwitch(.numbers))
        tap(.layerSwitch(.symbols))
        tap(.character("។"))
        tap(.character("៖"))
        for (id, character) in [(10, "។"), (11, "៖")] {
            down(id, .character(character))
            XCTAssertTrue(engine.handleCharacterHold(forTouch: id))
            up(id, .character(character))
        }
        XCTAssertEqual(engine.layout.key(.layerSwitch(.letters))?.label, "កខគ")
        tap(.returnKey)
        XCTAssertEqual(target.text, "0។ ។៖៙៚\n")
        XCTAssertEqual(engine.layout.layer, .letters)
        XCTAssertFalse(engine.isUppercase)
    }

    func testKhmerismEnglishPunctuationFollowsTheField() {
        useKhmerism()
        target.smartQuotesType = .yes
        target.smartDashesType = .yes
        tap(.layerSwitch(.numbers))
        for mark in ["\"", "-", "-", "\""] { tap(.character(mark)) }
        XCTAssertEqual(target.text, "“—”")
    }

    func testKhmerismTextReplacementWorksWithSpacePunctuationAndReturn() {
        useKhmerism()
        engine.autocorrect.isEnabled = false
        engine.autocorrect.loadLexiconEntries([("ហា", "សួស្តី")])
        tap(.character("ហ"))
        tap(.character("ា"))
        XCTAssertEqual(engine.suggestions.first(where: \.willAutoReplace)?.replacement, "សួស្តី")
        tap(.space)
        XCTAssertEqual(target.text, "សួស្តី ")

        tap(.character("ហ"))
        tap(.character("ា"))
        tap(.shift)
        tap(.character("ំ"))
        XCTAssertEqual(target.text, "សួស្តី សួស្តី។")

        tap(.space)
        tap(.character("ហ"))
        tap(.character("ា"))
        tap(.returnKey)
        XCTAssertEqual(target.text, "សួស្តី សួស្តី។ សួស្តី\n")
    }

    func testKhmerismUsesTheExistingEmojiKeyAction() {
        useKhmerism()
        engine.showsEmoji = true
        tap(.shift)
        tap(.layerSwitch(.numbers))
        var opened = 0
        engine.onEmojiKey = { opened += 1 }
        tap(.emoji)
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(engine.layout.layer, .numbers)
    }

    func testSpaceBeforeKhmerPunctuationFollowsTheActiveLayout() {
        for language: KeyboardLanguage in [.english, .khmer] {
            (target, engine) = swipeEngine("hello។")
            target.adjustTextPosition(byCharacterOffset: -1)
            engine.language = language
            tap(.space)
            XCTAssertEqual(target.text, language == .khmer ? "hello។" : "hello ។")
        }
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
        await engine.khmerDeleteRecovery?.value

        XCTAssertEqual(target.text, "ខ្ញុំចំនុច ")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerDeleteRecoveryDoesNotWriteWithoutADocumentIdentifier() async {
        let textTarget = KhmerScalarDeletingTarget(text: "ខ្ញុំចំនុច")
        textTarget.laggingReadsAfterDeleting = 6
        target = textTarget
        engine = FullKeyboardEngine(target: target, autocorrect: AutocorrectEngine(learnedWords: LearnedWordsStore(defaults: defaults)))
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)

        let immediateText = target.text
        XCTAssertTrue(immediateText.hasSuffix(" "), "The literal space did not wait for a delayed edit")
        XCTAssertNil(engine.khmerDeleteRecovery)
        await engine.khmerDeleteRecovery?.value
        XCTAssertEqual(target.text, immediateText, "An unidentified field must not receive a delayed edit")
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

        await recovery.value

        XCTAssertEqual(target.text, nextFieldText)
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

            await recovery.value

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

    func testKhmerCorrectionDoesNotOfferUndoWithoutADocumentIdentifier() async {
        target.insertText("ចំនុច")
        engine.language = .khmer
        await engine.khmerAutocompleteLoad?.value

        tap(.space)
        XCTAssertEqual(target.text, "ចំណុច")
        XCTAssertFalse(engine.suggestions.contains { $0.kind == .revert })
    }

    func testKhmerWordDeletionLeavesAnIncompleteRunToNormalBackspace() async {
        target = KhmerScalarDeletingTarget(text: "ខ្ញុំស្")
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
        await engine.khmerDeleteRecovery?.value
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

    func testDoubleTapShiftLocks() {
        tap(.shift)
        now += 0.1
        tap(.shift)
        type("hi")
        XCTAssertEqual(target.text, "HI")
        XCTAssertEqual(engine.shift.state, .locked)
    }

    /// Settings › Experiments › Dvorak punctuation keys: on English's Dvorak letters the three
    /// keys type `<`, `>` and `:` while shift is on, their keycaps and pop-ups read so, one-shot
    /// shift turns off after one as it does for a letter, and caps lock keeps them shifted.
    func testDvorakPunctuationTypesShiftedSymbols() throws {
        engine.width = 402
        engine.letterLayout = .dvorak
        XCTAssertNil(engine.layout.key(.character(",")), "off: Apple's seven-letter row 1")
        engine.dvorakPunctuation = true
        XCTAssertEqual(engine.layout.letters, .dvorak)
        let comma = try XCTUnwrap(engine.layout.key(.character(",")))
        let period = try XCTUnwrap(engine.layout.key(.character(".")))
        let semicolon = try XCTUnwrap(engine.layout.key(.character(";")))
        XCTAssertEqual(comma.shifted, "<")
        XCTAssertEqual(period.shifted, ">")
        XCTAssertEqual(semicolon.shifted, ":")
        XCTAssertEqual(comma.row, 0)
        XCTAssertEqual(period.row, 0)
        XCTAssertEqual(semicolon.row, 3)
        XCTAssertEqual(engine.keycapLabel(for: comma), ",")
        XCTAssertEqual(engine.displayLabel(for: comma), ",")
        XCTAssertEqual(engine.keycapLabel(for: semicolon), ";")
        tap(.shift)
        XCTAssertEqual(engine.keycapLabel(for: comma), "<")
        XCTAssertEqual(engine.displayLabel(for: comma), "<")
        XCTAssertEqual(engine.keycapLabel(for: period), ">")
        XCTAssertEqual(engine.displayLabel(for: period), ">")
        XCTAssertEqual(engine.keycapLabel(for: semicolon), ":")
        XCTAssertEqual(engine.displayLabel(for: semicolon), ":")
        tap(.character(","))
        XCTAssertEqual(target.text, "<")
        XCTAssertEqual(engine.shift.state, .off, "one-shot, as after a letter")
        XCTAssertEqual(engine.keycapLabel(for: comma), ",")
        tap(.character("."))
        tap(.character(";"))
        XCTAssertEqual(target.text, "<.;")
        tap(.shift)
        now += 0.1
        tap(.shift)
        XCTAssertEqual(engine.shift.state, .locked)
        tap(.character(","))
        tap(.character("."))
        tap(.character(";"))
        XCTAssertEqual(target.text, "<.;<>:")
        XCTAssertEqual(engine.shift.state, .locked, "caps lock stays on")
        XCTAssertEqual(engine.keycapLabel(for: semicolon), ":")
        // The narrower row 1 is its own key plane for Adaptive touch: what it learns stays there.
        let punctuation = try XCTUnwrap(AdaptiveTouchGeometry(layout: engine.layout)).key
        engine.dvorakPunctuation = false
        XCTAssertNotEqual(try XCTUnwrap(AdaptiveTouchGeometry(layout: engine.layout)).key, punctuation)
    }

    /// Settings › Experiments › Dvorak punctuation keys: a URL or email field already has its own
    /// `.` key on the bottom row, so its Dvorak row 1 stays Apple's rather than have two keys
    /// that type the same character, while the semicolon still joins the space bar.
    func testDvorakPunctuationKeepsFieldsOwnPeriodKey() throws {
        engine.width = 402
        engine.letterLayout = .dvorak
        engine.dvorakPunctuation = true
        for keyboardType in [UIKeyboardType.URL, .emailAddress, .webSearch] {
            target.keyboardType = keyboardType
            engine.configureForField()
            XCTAssertNotEqual(engine.layout.field, .text, "\(keyboardType.rawValue)")
            XCTAssertEqual(engine.layout.keys.filter { $0.kind == .character(".") }.count, 1, "the field's own . only")
            XCTAssertNil(engine.layout.key(.character(",")), "row 1 stays Apple's")
            XCTAssertEqual(engine.layout.key(.character("."))?.row, 3)
            XCTAssertEqual(engine.layout.key(.character(";"))?.shifted, ":")
            XCTAssertEqual(engine.layout.key(.character(";"))?.row, 3)
        }
    }

    /// Settings › Experiments › Dvorak punctuation keys: auto-capitalization's shift types no
    /// symbols — a comma at a sentence's start stays a comma, and its keycap reads so — while a
    /// shift you press, or caps lock, types `<`, and the semicolon `:`.
    func testDvorakPunctuationFollowsAUserShiftNotAutoCapitalization() throws {
        engine.width = 402
        engine.letterLayout = .dvorak
        engine.dvorakPunctuation = true
        target.autocapitalizationType = .sentences
        engine.configureForField()
        let comma = try XCTUnwrap(engine.layout.key(.character(",")))
        XCTAssertEqual(engine.shift.state, .on, "the field's first sentence")
        XCTAssertFalse(engine.shift.isUserShift)
        XCTAssertEqual(engine.keycapLabel(for: comma), ",")
        XCTAssertEqual(engine.displayLabel(for: comma), ",")
        tap(.character(","))
        XCTAssertEqual(target.text, ",")
        XCTAssertEqual(engine.shift.state, .off)

        type("ok. ")
        XCTAssertEqual(target.text, ",ok. ")
        XCTAssertEqual(engine.shift.state, .on, "after a sentence")
        XCTAssertFalse(engine.shift.isUserShift)
        tap(.character(","))
        XCTAssertEqual(target.text, ",ok. ,")

        tap(.shift)
        XCTAssertTrue(engine.shift.isUserShift)
        XCTAssertEqual(engine.keycapLabel(for: comma), "<")
        tap(.character(","))
        XCTAssertEqual(target.text, ",ok. ,<")
        XCTAssertEqual(engine.shift.state, .off, "one-shot")

        tap(.shift)
        now += 0.1
        tap(.shift)
        XCTAssertEqual(engine.shift.state, .locked)
        XCTAssertTrue(engine.shift.isUserShift)
        XCTAssertEqual(engine.keycapLabel(for: comma), "<")
        tap(.character(";"))
        XCTAssertEqual(target.text, ",ok. ,<:")
    }

    /// Settings › Experiments › Comma and period keys: the flag rebuilds the layout with a comma
    /// just left of the space bar and a period just right of it, which type themselves (shift
    /// leaves them as they are), and only on an iPhone's letters page in a text field.
    func testCommaAndPeriodKeysTypeByTheSpaceBar() throws {
        engine.width = 402
        XCTAssertFalse(engine.layout.commaPeriodKeys)
        XCTAssertNil(engine.layout.key(.character(",")))
        XCTAssertNil(engine.layout.key(.character(".")))
        engine.commaPeriodKeys = true
        XCTAssertTrue(engine.layout.commaPeriodKeys)
        let comma = try XCTUnwrap(engine.layout.key(.character(",")))
        let period = try XCTUnwrap(engine.layout.key(.character(".")))
        let space = try XCTUnwrap(engine.layout.key(.space))
        XCTAssertEqual(comma.row, 3)
        XCTAssertEqual(period.row, 3)
        XCTAssertNil(comma.shifted)
        XCTAssertNil(period.shifted)
        let gap = engine.layout.metrics.gap
        XCTAssertEqual(comma.frame.maxX + gap, space.frame.minX, accuracy: 0.001)
        XCTAssertEqual(space.frame.maxX + gap, period.frame.minX, accuracy: 0.001)
        XCTAssertEqual(engine.keycapLabel(for: comma), ",")
        XCTAssertEqual(engine.displayLabel(for: period), ".")
        tap(.character(","))
        XCTAssertEqual(target.text, ",")
        tap(.character("."))
        XCTAssertEqual(target.text, ",.")
        tap(.shift)
        XCTAssertEqual(engine.keycapLabel(for: comma), ",", "no shifted symbols")
        XCTAssertEqual(engine.displayLabel(for: period), ".")
        tap(.character(","))
        tap(.character("."))
        XCTAssertEqual(target.text, ",.,.")
        XCTAssertEqual(engine.shift.state, .off, "one-shot, as after any character")

        // The 123 page keeps its own punctuation row, so neither key sits on its bottom row.
        tap(.layerSwitch(.numbers))
        XCTAssertNil(engine.layout.keys.first { $0.row == 3 && $0.kind == .character(",") })
        XCTAssertNil(engine.layout.keys.first { $0.row == 3 && $0.kind == .character(".") })
        tap(.layerSwitch(.letters))
        for keyboardType in [UIKeyboardType.URL, .emailAddress, .webSearch] {
            target.keyboardType = keyboardType
            engine.configureForField()
            XCTAssertNotEqual(engine.layout.field, .text, "\(keyboardType.rawValue)")
            XCTAssertNil(engine.layout.key(.character(",")), "no comma key")
            XCTAssertEqual(engine.layout.keys.filter { $0.kind == .character(".") }.count, 1, "the field's own .")
            XCTAssertEqual(engine.layout.key(.character("."))?.row, 3)
        }
        target.keyboardType = .default
        engine.configureForField()
        engine.pad = .docked(.mini)
        XCTAssertFalse(engine.layout.commaPeriodKeys)
        XCTAssertNil(engine.layout.keys.first { $0.row == 3 && $0.kind == .character(",") }, "an iPad keeps Apple's bottom row")
        XCTAssertNil(engine.layout.keys.first { $0.row == 3 && $0.kind == .character(".") })
        XCTAssertEqual(engine.layout.key(.character(","))?.row, 2, "the docked iPad's own pair")
        engine.pad = nil
        engine.letterLayout = .dvorak
        engine.dvorakPunctuation = true
        XCTAssertFalse(engine.layout.commaPeriodKeys, "Dvorak punctuation already has both on row 1")
        XCTAssertEqual(engine.layout.key(.character(","))?.row, 0)
        XCTAssertEqual(engine.layout.key(.character(";"))?.row, 3)
    }

    func testHoldNumbersSlideToADigitAndLetGo() {
        down(1, .layerSwitch(.numbers))
        XCTAssertEqual(engine.layout.layer, .numbers)
        engine.touchMoved(id: 1, to: point(.character("7")))
        engine.touchEnded(id: 1, at: point(.character("7")))
        XCTAssertEqual(target.text, "7")
        XCTAssertEqual(engine.layout.layer, .letters)
    }

    /// As on Apple's keyboard, the key under the finger shows its pop-up the whole slide.
    func testHoldNumbersPreviewsTheKeyUnderTheFinger() {
        down(1, .layerSwitch(.numbers))
        XCTAssertNil(engine.previewKey, "123 itself has no pop-up")
        engine.touchMoved(id: 1, to: point(.character("5")))
        XCTAssertEqual(engine.previewKey?.kind, .character("5"))
        XCTAssertTrue(engine.pressedKinds.contains(.character("5")), "with Key pop-ups off it darkens")
        engine.touchMoved(id: 1, to: point(.character("6")))
        XCTAssertEqual(engine.previewKey?.kind, .character("6"))
        engine.touchMoved(id: 1, to: point(.space))
        XCTAssertNil(engine.previewKey, "no pop-up over a key that isn't a character")
        engine.touchMoved(id: 1, to: CGPoint(x: point(.character("6")).x, y: engine.layout.touchAreaFrame.minY - 40))
        XCTAssertNil(engine.previewKey, "none off the keys")
        engine.touchMoved(id: 1, to: point(.character("(")))
        XCTAssertEqual(engine.previewKey?.kind, .character("("))
        engine.touchEnded(id: 1, at: point(.character("(")))
        XCTAssertNil(engine.previewKey)
        XCTAssertEqual(target.text, "(")
        XCTAssertEqual(engine.layout.layer, .letters)
    }

    func testLiftingBackOnTheNumbersKeyOrOffTheKeysTypesNothing() {
        down(1, .layerSwitch(.numbers))
        engine.touchMoved(id: 1, to: point(.character("5")))
        let abc = point(.layerSwitch(.letters))
        engine.touchMoved(id: 1, to: abc)
        XCTAssertNil(engine.previewKey)
        engine.touchEnded(id: 1, at: abc)
        XCTAssertEqual(target.text, "")
        XCTAssertEqual(engine.layout.layer, .letters, "a slide taken back goes back to the letters")

        down(2, .layerSwitch(.numbers))
        engine.touchMoved(id: 2, to: point(.character("5")))
        let above = CGPoint(x: point(.character("5")).x, y: engine.layout.touchAreaFrame.minY - 40)
        engine.touchMoved(id: 2, to: above)
        engine.touchEnded(id: 2, at: above)
        XCTAssertEqual(target.text, "")
        XCTAssertEqual(engine.layout.layer, .numbers, "off the keys the numbers stay, as on Apple's keyboard")

        tap(.layerSwitch(.letters))
        tap(.layerSwitch(.numbers))
        XCTAssertEqual(engine.layout.layer, .numbers, "a tap of 123 still stays on the numbers")
        XCTAssertEqual(target.text, "")
    }

    func testHoldSymbolsSlideToASymbolAndLetGo() {
        tap(.layerSwitch(.numbers))
        down(1, .layerSwitch(.symbols))
        XCTAssertEqual(engine.layout.layer, .symbols)
        engine.touchMoved(id: 1, to: point(.character("%")))
        XCTAssertEqual(engine.previewKey?.kind, .character("%"))
        engine.touchEnded(id: 1, at: point(.character("%")))
        XCTAssertEqual(target.text, "%")
        XCTAssertEqual(engine.layout.layer, .numbers, "back to the page it came from")
    }

    func testHoldShiftSlideToALetterTypesACapital() {
        down(1, .shift)
        engine.touchMoved(id: 1, to: point(.character("h")))
        XCTAssertEqual(engine.previewKey?.kind, .character("h"))
        XCTAssertEqual(engine.previewKey.map(engine.displayLabel(for:)), "H")
        engine.touchEnded(id: 1, at: point(.character("h")))
        XCTAssertEqual(target.text, "H")
        XCTAssertEqual(engine.shift.state, .off)
        tap(.character("i"))
        XCTAssertEqual(target.text, "Hi")

        // Slid off and back onto shift: a tap of shift, nothing typed.
        down(2, .shift)
        engine.touchMoved(id: 2, to: point(.character("z")))
        engine.touchMoved(id: 2, to: point(.shift))
        XCTAssertNil(engine.previewKey)
        engine.touchEnded(id: 2, at: point(.shift))
        XCTAssertEqual(target.text, "Hi")
        XCTAssertEqual(engine.shift.state, .on)
    }

    func testNumbersStayUntilSpace() {
        tap(.layerSwitch(.numbers))
        XCTAssertEqual(engine.layout.layer, .numbers)
        tap(.character("4"))
        tap(.character("2"))
        XCTAssertEqual(engine.layout.layer, .numbers)
        tap(.space)
        XCTAssertEqual(engine.layout.layer, .letters)
        XCTAssertEqual(target.text, "42 ")
    }

    func testDoubleSpaceTypesAPeriod() {
        type("ok")
        tap(.space)
        now += 0.2
        tap(.space)
        XCTAssertEqual(target.text, "ok. ")
        now += 0.2
        tap(.space)
        XCTAssertEqual(target.text, "ok.  ", "a third space is just a space")
    }

    func testSlowDoubleSpaceStaysTwoSpaces() {
        type("ok")
        tap(.space)
        now += 0.5
        tap(.space)
        XCTAssertEqual(target.text, "ok  ")
    }

    func testSentenceAutoCapitalization() {
        target.autocapitalizationType = .sentences
        engine.configureForField()
        XCTAssertEqual(engine.shift.state, .on)
        type("hi")
        tap(.space)
        now += 0.2
        tap(.space)
        type("there")
        XCTAssertEqual(target.text, "Hi. There")
    }

    /// Settings › Keyboard › Auto-capitalization off, as Apple's switch: shift never turns
    /// itself on, whatever the field asks, not even after the double-space period; shift and
    /// caps lock still work.
    func testAutoCapitalizationOffNeverTurnsShiftOn() {
        engine.autoCapitalizes = false
        for type in [UITextAutocapitalizationType.sentences, .words, .allCharacters] {
            target.autocapitalizationType = type
            engine.configureForField()
            XCTAssertEqual(engine.shift.state, .off, "autocapitalizationType \(type.rawValue)")
        }
        target.autocapitalizationType = .sentences
        engine.configureForField()
        type("hi")
        tap(.space)
        now += 0.2
        tap(.space)
        XCTAssertEqual(engine.shift.state, .off, "after the double-space period")
        type("there ok")
        tap(.shift)
        type("x")
        tap(.shift)
        tap(.shift)
        type("yz")
        XCTAssertEqual(target.text, "hi. there okXYZ", "shift, then caps lock")

        tap(.shift)
        tap(.space)
        now += 0.2
        tap(.space)
        XCTAssertEqual(target.text, "hi. there okXYZ. ")
        XCTAssertEqual(engine.shift.state, .off)
        engine.autoCapitalizes = true
        XCTAssertEqual(engine.shift.state, .on, "switched back on, the next sentence starts with a capital")
    }

    func testAcceleratingDeleteRampAndWordDelete() {
        type("hello world")
        down(1, .delete)
        XCTAssertEqual(target.text, "hello worl")
        // Initial repeat deletes 1 char.
        engine.repeatDelete(heldFor: FullKeyboardEngine.repeatDelay)
        XCTAssertEqual(target.text, "hello wor")
        // Accelerated repeat deletes 2 chars per tick.
        engine.repeatDelete(heldFor: FullKeyboardEngine.fastRepeatAfter)
        XCTAssertEqual(target.text, "hello w")
        // After 1.4 s, removes whole words backward.
        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)
        XCTAssertEqual(target.text, "hello ")
        engine.repeatDelete(heldFor: FullKeyboardEngine.wordDeleteAfter)
        XCTAssertEqual(target.text, "")
        up(1, .delete)
    }

    func testLongPressAccentPickerSelectsAndUppercaseWorks() {
        tap(.shift)
        down(1, .character("e"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 1))
        let menu = try! XCTUnwrap(engine.activeAccentMenu)
        XCTAssertNil(engine.previewKey, "single-key balloon hides while accent picker is open")
        // Apple's order, capitals while shift is on, opening on the key's own letter.
        XCTAssertEqual(menu.options, ["Ë", "É", "E", "È", "Ê", "Ě", "Ẽ", "Ē", "Ė", "Ę"])
        XCTAssertEqual(menu.selectedOption, "E")
        let cell = menu.cellFrames[menu.options.firstIndex(of: "É")!]
        engine.touchMoved(id: 1, to: CGPoint(x: cell.midX, y: cell.midY))
        engine.touchEnded(id: 1, at: CGPoint(x: cell.midX, y: cell.midY))
        XCTAssertNil(engine.activeAccentMenu)
        XCTAssertEqual(target.text, "É")
        XCTAssertEqual(engine.shift.state, .off)
    }

    /// Settings › Experiments › Quick accents: a held letter's callout opens on its language's
    /// preferred accent (Spanish O's ó, though the callout lists ö first), so letting go where
    /// it opened types it, sliding into another cell still picks that one, and another key
    /// going down commits the preselection too. Letting go far below still cancels. Off, the
    /// key's own stays selected, as before.
    func testQuickAccentsOpensOnTheMainAccentAndTypesItOnRelease() {
        engine.language = .spanish
        XCTAssertFalse(FullKeyboardSettings(defaults: defaults).quickAccents, "off by default")
        engine.quickAccentsEnabled = true

        down(1, .character("o"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 1))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "ó", "o's preferred accent, not the callout's ö")
        // A finger that hasn't left the cell it opened over leaves the preselection alone.
        engine.touchMoved(id: 1, to: point(.character("o")))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "ó")
        up(1, .character("o"))
        XCTAssertEqual(target.text, "ó")

        // Sliding into another cell still picks it.
        down(2, .character("e"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 2))
        let menu = try! XCTUnwrap(engine.activeAccentMenu)
        XCTAssertEqual(menu.selectedOption, "é")
        let cell = menu.cellFrames[menu.options.firstIndex(of: "è")!]
        engine.touchMoved(id: 2, to: CGPoint(x: cell.midX, y: cell.midY))
        engine.touchEnded(id: 2, at: CGPoint(x: cell.midX, y: cell.midY))
        XCTAssertEqual(target.text, "óè")

        // Another key going down while the callout is held commits what it preselected.
        down(3, .character("a"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 3))
        down(4, .character("b"))
        up(4, .character("b"))
        up(3, .character("a"))
        XCTAssertEqual(target.text, "óèáb")

        // Capitals use the callout's own uppercase mapping.
        tap(.shift)
        down(5, .character("a"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 5))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "Á")
        up(5, .character("a"))
        XCTAssertEqual(target.text, "óèábÁ")

        engine.quickAccentsEnabled = false
        down(6, .character("a"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 6))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "a", "off: the key's own, as before")
        up(6, .character("a"))
        XCTAssertEqual(target.text, "óèábÁa")

        // English e picks é too, though its callout lists ë first.
        engine.language = .english
        engine.quickAccentsEnabled = true
        down(7, .character("e"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 7))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "é")
        up(7, .character("e"))
        XCTAssertEqual(target.text, "óèábÁaé")

        // Letting go far below still cancels the preselection, typing nothing.
        engine.language = .spanish
        let o = point(.character("o"))
        down(8, .character("o"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 8))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "ó")
        engine.touchEnded(id: 8, at: CGPoint(x: o.x, y: o.y + FullKeyboardEngine.accentCancelDrop + 5))
        XCTAssertNil(engine.activeAccentMenu)
        XCTAssertEqual(target.text, "óèábÁaé")

        // The 123 page's held symbols keep the key's own selected.
        tap(.layerSwitch(.numbers))
        down(9, .character("1"))
        XCTAssertTrue(engine.openAccentMenuIfEligible(forTouch: 9))
        XCTAssertEqual(engine.activeAccentMenu?.selectedOption, "1")
        up(9, .character("1"))
        XCTAssertEqual(target.text, "óèábÁaé1")
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
private final class KhmerNilBeforeStartTarget: FixtureTextTarget {
    override var documentContextBeforeInput: String? {
        guard cursorIndex > 0 else { return nil }
        return super.documentContextBeforeInput
    }
}
