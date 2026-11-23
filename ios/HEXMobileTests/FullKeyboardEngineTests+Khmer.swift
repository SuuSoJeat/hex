import UIKit
import XCTest
@testable import HEX

extension FullKeyboardEngineTests {
    func useKhmerism() {
        target.documentIdentifier = target.documentIdentifier ?? UUID()
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
            target.documentIdentifier = UUID()
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
}
