import CoreGraphics
import XCTest
@testable import HEX

extension KeyboardLayoutTests {
    func testStandardKhmerMatchesNativeKeyOrderOnEveryPage() {
        let makeLayout = { (layer: KeyboardLayer) in
            KeyboardLayout(width: 440, layer: layer, showsGlobe: true, showsEmoji: true, language: .khmer, letters: .khmer)
        }
        let layout = makeLayout(.letters)
        let base = [
            ["១", "២", "៣", "៤", "៥", "៦", "៧", "៨", "៩", "០", "ឥ", "ឲ"],
            ["ឆ", "ឹ", "េ", "រ", "ត", "យ", "ុ", "ិ", "ោ", "ផ", "ៀ", "ឪ"],
            ["ា", "ស", "ដ", "ថ", "ង", "ហ", "្", "ក", "ល", "ើ", "់", "ឭ"],
            ["ឋ", "ខ", "ច", "វ", "ប", "ន", "ម", "ឦ", "។", "៊"],
        ]
        let shifted = [
            ["!", "ៗ", "\"", "៛", "%", "៍", "័", "៏", "ឰ", "ឳ", "៌", "៎"],
            ["ឈ", "ឺ", "ែ", "ឬ", "ទ", "ួ", "ូ", "ី", "ៅ", "ភ", "ឿ", "ឧ"],
            ["ឫ", "ៃ", "ឌ", "ធ", "អ", "ះ", "ញ", "គ", "ឡ", "៖", "៉", "ឮ"],
            ["ឍ", "ឃ", "ជ", "ៈ", "ព", "ណ", "ំ", "ឱ", "៕", "ឯ"],
        ]
        for row in base.indices {
            let keys = layout.keys.filter { $0.row == row && $0.character != nil }
            XCTAssertEqual(keys.compactMap(\.character), base[row])
            XCTAssertEqual(keys.compactMap(\.shifted), shifted[row])
            for key in keys {
                XCTAssertEqual(layout.hitTest(CGPoint(x: key.frame.midX, y: key.frame.midY)), key)
            }
        }
        XCTAssertEqual(layout.bottomRowIndex, 4)
        XCTAssertEqual(layout.keys.filter { $0.row == 3 }.first?.kind, .shift)
        XCTAssertEqual(layout.keys.filter { $0.row == 3 }.last?.kind, .delete)
        XCTAssertEqual(layout.keys.filter { $0.row == 4 }.map(\.kind), [.layerSwitch(.numbers), .globe, .emoji, .space, .returnKey])

        let numbers = makeLayout(.numbers)
        XCTAssertEqual(numbers.bottomRowIndex, 3)
        XCTAssertEqual(letters(numbers, row: 0), KeyboardLayout.numberRowDigits)
        XCTAssertEqual(letters(numbers, row: 1), ["«", "»", "@", "៑", "៛", "/", "៙", "៚", "(", ")"])
        XCTAssertEqual(letters(numbers, row: 2), ["ឩ", "ឝ", "ឞ", "?", "!"])
        XCTAssertEqual(numbers.key(.layerSwitch(.letters))?.label, "ក")

        let symbols = makeLayout(.symbols)
        XCTAssertEqual(symbols.bottomRowIndex, 3)
        XCTAssertEqual(letters(symbols, row: 0), ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        XCTAssertEqual(letters(symbols, row: 1), ["-", "_", ":", ";", "<", ">", "$", "£", "€", "•"])
        XCTAssertEqual(letters(symbols, row: 2), [".", ",", "'", "?", "!"])
    }

    func testStandardKhmerKeepsTheSharedHexAndGlobePlacement() throws {
        for placement in HexKeyPlacement.allCases {
            let layout = KeyboardLayout(
                width: 402, showsGlobe: true, language: .khmer, letters: .khmer, hexPlacement: placement
            )
            let globe = try XCTUnwrap(layout.key(.globe))
            let hex = try XCTUnwrap(layout.key(.hex))
            let space = try XCTUnwrap(layout.key(.space))
            XCTAssertEqual(layout.hexPlacement, placement)
            XCTAssertEqual(globe.row, layout.bottomRowIndex)
            XCTAssertLessThan(globe.frame.midX, space.frame.midX)
            if placement.isInStrip {
                let english = KeyboardLayout(width: 402, hexPlacement: placement)
                XCTAssertEqual(hex, english.key(.hex))
                XCTAssertEqual(layout.stripFrame, english.stripFrame)
            } else {
                XCTAssertEqual(hex.row, layout.bottomRowIndex)
                XCTAssertEqual(hex.frame.midX < space.frame.midX, placement == .leftOfSpace)
            }
        }

        for layer in layers {
            let pad = KeyboardLayout(
                width: 744, layer: layer, showsGlobe: true, showsEmoji: true,
                language: .khmer, letters: .khmer, pad: .docked(.mini), commaPeriodKeys: true
            )
            let footer = pad.keys.filter { $0.row == pad.bottomRowIndex }.map(\.kind)
            let page: KeyKind = .layerSwitch(layer == .letters ? .numbers : .letters)
            XCTAssertEqual(pad.hexPlacement, .leftOfSpace)
            XCTAssertEqual(footer, [.globe, page, .hex, .space, .returnKey, .emoji, .dismiss])
            XCTAssertFalse(pad.commaPeriodKeys)
            XCTAssertEqual(pad.stripFrame, pad.stripBarFrame)
        }
    }

    func testStandardKhmerFollowsTheDuoSplitPreferenceOnEveryPage() throws {
        for layer in layers {
            let split = KeyboardLayout(
                width: 801, layer: layer, field: .email, showsGlobe: true, showsEmoji: true,
                language: .khmer, letters: .khmer, posture: .unfoldedWide, windowInset: 75, numberRow: true
            )
            let joined = KeyboardLayout(
                width: 801, layer: layer, field: .email, showsGlobe: true, showsEmoji: true,
                language: .khmer, letters: .khmer, posture: .unfoldedWide, windowInset: 75, numberRow: true,
                joinsUnfoldedKeyboard: true
            )
            let gap = try XCTUnwrap(split.split)
            XCTAssertFalse(joined.isSplit)
            XCTAssertEqual(split.totalHeight, joined.totalHeight, accuracy: 0.001)
            XCTAssertEqual(split.bottomRowIndex, layer == .letters ? 4 : 3)
            XCTAssertEqual(split.keys.filter { $0.kind == .space }.count, 2)
            XCTAssertEqual(joined.keys.filter { $0.kind == .space }.count, 1)
            XCTAssertEqual(split.key(.globe)?.row, split.bottomRowIndex)
            XCTAssertEqual(joined.key(.globe)?.row, joined.bottomRowIndex)
            XCTAssertEqual(split.keys.filter(\.isNumberRow).map(\.label), layer == .numbers ? [] : KeyboardLayout.numberRowDigits)
            XCTAssertEqual(Array(split.keys.filter { $0.row == split.bottomRowIndex }.suffix(3).map(\.kind)),
                           [.character("@"), .character("."), .returnKey])
            for row in 0..<split.bottomRowIndex {
                let expected = joined.keys.filter { $0.row == row && $0.character != nil }
                let actual = split.keys.filter { $0.row == row && $0.character != nil }
                let halves = SplitGeometry.halves(expected.map(\.label))
                XCTAssertEqual(actual.map(\.label), halves.left + halves.right)
                for key in actual {
                    XCTAssertEqual(key.shifted, expected.first { $0.label == key.label }?.shifted)
                    XCTAssertEqual(split.hitTest(CGPoint(x: key.frame.midX, y: key.frame.midY)), key)
                }
                XCTAssertNil(split.hitTest(CGPoint(x: gap.middle, y: actual[0].frame.midY)))
            }
        }
    }

    func testStandardKhmerAddsOptionalCommaAndPeriodBesideSpace() throws {
        let phone = KeyboardLayout(width: 375, showsGlobe: true, showsEmoji: true, language: .khmer, letters: .khmer, commaPeriodKeys: true)
        let split = KeyboardLayout(
            width: 801, showsGlobe: true, showsEmoji: true, language: .khmer, letters: .khmer,
            posture: .unfoldedWide, windowInset: 75, commaPeriodKeys: true
        )
        for layout in [phone, split] {
            let comma = try XCTUnwrap(layout.key(.character(",")))
            let period = try XCTUnwrap(layout.key(.character(".")))
            let spaces = layout.keys.filter { $0.kind == .space }
            let gap = layout.isSplit ? SplitGeometry.gap : layout.metrics.gap
            XCTAssertEqual(comma.row, layout.bottomRowIndex)
            XCTAssertEqual(period.row, layout.bottomRowIndex)
            XCTAssertEqual(comma.frame.maxX + gap, spaces[0].frame.minX, accuracy: 0.001)
            XCTAssertEqual(period.frame.minX, spaces[spaces.count - 1].frame.maxX + gap, accuracy: 0.001)
            XCTAssertTrue(spaces.allSatisfy { $0.frame.width >= comma.frame.width })
        }
    }

    func testKhmerismLaysOutEveryPageWithReachableControls() {
        let screens: [(CGFloat, KeyboardOrientation, KeyboardPhoneSize, KeyboardPosture, CGFloat, KeyboardPadPlacement?)] = [
            (320, .portrait, .regular, .phone, 0, .floating),
            (375, .portrait, .homeButton, .phone, 0, nil),
            (440, .portrait, .large, .phone, 0, nil),
            (667, .landscape, .homeButton, .phone, 0, nil),
            (452, .portrait, .regular, .cover, 7, nil),
            (801, .portrait, .regular, .unfoldedWide, 75, nil),
            (744, .portrait, .regular, .phone, 0, .docked(.mini)),
            (1032, .portrait, .regular, .phone, 0, .docked(.large)),
        ]
        for (width, orientation, phoneSize, posture, windowInset, pad) in screens {
            for layer in layers {
                let layout = KeyboardLayout(
                    width: width, orientation: orientation, layer: layer, showsGlobe: true, showsEmoji: true,
                    language: .khmer, letters: .khmerism, posture: posture, windowInset: windowInset, phoneSize: phoneSize, pad: pad
                )
                let label = "\(width) \(layer)"
                XCTAssertFalse(layout.isSplit, label)
                XCTAssertFalse(layout.hasNumberRow, label)
                XCTAssertEqual(layout.totalHeight, KeyboardLayout.height(
                    for: orientation, posture: posture, phoneSize: phoneSize, pad: pad, language: .khmer,
                    layer: layer, letters: .khmerism
                ), accuracy: 0.001, label)
                let footerRow = layer == .letters ? 4 : 3
                XCTAssertEqual(layout.bottomRowIndex, footerRow, label)
                XCTAssertEqual(layout.key(.globe)?.row, -1, label)
                XCTAssertEqual(layout.key(.hex)?.row, -1, label)
                let footer = layout.keys.filter { $0.row == footerRow }
                XCTAssertEqual(footer[0].label, layer == .letters ? "123" : "កខគ", label)
                XCTAssertEqual(footer[1].kind, .emoji, label)
                XCTAssertEqual(footer[2].label, "ខ្មែរ", label)
                XCTAssertEqual(layout.key(.returnKey)?.row, footerRow, label)
                XCTAssertEqual(layout.key(.delete)?.row, footerRow - 1, label)
                let pageKey: KeyKind = switch layer {
                case .letters: .shift
                case .numbers: .layerSwitch(.symbols)
                case .symbols: .layerSwitch(.numbers)
                }
                XCTAssertEqual(layout.keys.first { $0.row == footerRow - 1 }?.kind, pageKey, label)
                let rows: [[String]] = switch layer {
                case .letters: KhmerismLayout.base.map { $0.map(\.text) }
                case .numbers: KeyboardLayout.characterRows(for: .numbers) + [["។", "៕"]]
                case .symbols: KeyboardLayout.characterRows(for: .symbols) + [["។", "៖"]]
                }
                let firstKey = layout.keys.first { $0.row == 0 }
                let stripBottom = layout.metrics.stripTop + layout.metrics.stripHeight
                XCTAssertEqual(firstKey?.frame.minY ?? 0, layout.metrics.stripArea, accuracy: 0.001, label)
                XCTAssertGreaterThanOrEqual((firstKey?.frame.minY ?? 0) - stripBottom, KeyboardMetrics.stripGap, label)
                XCTAssertEqual(firstKey?.hitFrame.minY, layout.touchAreaFrame.minY, label)
                XCTAssertEqual(Set(layout.keys.filter { $0.row >= 0 }.map(\.row)), Set(0...footerRow), label)
                for (row, page) in rows.enumerated() {
                    XCTAssertEqual(letters(layout, row: row), page, label)
                    let rowKeys = layout.keys.filter { $0.row == row }
                    XCTAssertEqual(rowKeys.first?.hitFrame.minX, 0, label)
                    XCTAssertEqual(rowKeys.last?.hitFrame.maxX ?? -1, width, accuracy: 0.001, label)
                    for (left, right) in zip(rowKeys, rowKeys.dropFirst()) where left.kind != .emoji && right.kind != .emoji {
                        XCTAssertEqual(left.hitFrame.maxX, right.hitFrame.minX, accuracy: 0.001, label)
                    }
                    for key in rowKeys {
                        XCTAssertGreaterThan(key.frame.width, 20, "\(label) \(key.label)")
                        XCTAssertEqual(layout.hitTest(CGPoint(x: key.frame.midX, y: key.frame.midY)), key, label)
                    }
                }
            }
        }
    }

    func testKhmerismWebSearchKeepsKhmerPunctuationAndAddsAPeriod() {
        let layout = KeyboardLayout(width: 402, layer: .numbers, field: .webSearch, language: .khmer, letters: .khmerism)
        let footer = layout.keys.filter { $0.row == layout.bottomRowIndex }.map(\.kind)
        XCTAssertTrue(footer.contains(.character(".")))
        XCTAssertTrue(footer.contains(.character("។")))
    }

    func testKhmerLayoutsKeepFieldKeysBeforeReturn() {
        let fields: [(KeyboardFieldKind, [KeyKind])] = [
            (.webSearch, [.character(".")]),
            (.url, [.character("."), .character("/")]),
            (.email, [.character("@"), .character(".")]),
        ]
        for letters in [KeyboardLetterLayout.khmerism, .khmer] {
            for layer in [KeyboardLayer.letters, .numbers, .symbols] {
                for (field, keys) in fields {
                    let layout = KeyboardLayout(width: 402, layer: layer, field: field, language: .khmer, letters: letters)
                    let footer = layout.keys.filter { $0.row == layout.bottomRowIndex }.map(\.kind)
                    XCTAssertEqual(Array(footer.suffix(keys.count + 1)), keys + [.returnKey], describe(layout))
                }
            }
        }
    }

    func testKhmerismMatchesTheDesignerAtProMaxWidth() {
        let layout = KeyboardLayout(width: 440, showsGlobe: true, showsEmoji: true, language: .khmer, letters: .khmerism, phoneSize: .large)
        let native = KeyboardMetrics.phonePortrait(.large)
        XCTAssertEqual(layout.metrics.keyHeight, native.keyHeight, accuracy: 0.001)
        XCTAssertEqual(layout.metrics.rowGap, native.rowGap, accuracy: 0.001)
        XCTAssertEqual(layout.metrics.gap, native.gap, accuracy: 0.001)
        XCTAssertEqual(layout.metrics.side, native.side, accuracy: 0.001)
        XCTAssertEqual(layout.metrics.cornerRadius, native.cornerRadius, accuracy: 0.001)
        let footer = layout.keys.filter { $0.row == 4 }
        XCTAssertEqual(footer.map(\.label), ["123", "emoji", "ខ្មែរ", "ំ", "់", "↵"])
        let unit = footer[4].frame.width
        let ratios: [CGFloat] = [1.51, 1.14, 5.07, 1.01, 1, 2.21]
        for (key, ratio) in zip(footer, ratios) {
            XCTAssertEqual(key.frame.width / unit, ratio, accuracy: 0.001, key.label)
        }
    }

    func testKhmerismNumericCapsUseEnglishGeometry() {
        let base = KeyboardLayout(width: 440, showsEmoji: true, language: .khmer, letters: .khmerism, phoneSize: .large)
        let pitch = base.metrics.keyHeight + base.metrics.rowGap
        for layer in [KeyboardLayer.numbers, .symbols] {
            let numeric = KeyboardLayout(
                width: 440, layer: layer, showsEmoji: true, language: .khmer, letters: .khmerism, phoneSize: .large
            )
            let english = KeyboardLayout(width: 440, layer: layer, showsEmoji: true, phoneSize: .large)
            XCTAssertEqual(numeric.totalHeight, english.totalHeight, accuracy: 0.001)
            XCTAssertEqual(base.totalHeight - numeric.totalHeight, pitch, accuracy: 0.001)
            XCTAssertEqual(numeric.key(.space)?.frame, base.key(.space)?.frame.offsetBy(dx: 0, dy: -pitch))
            let firstRowPoint = CGPoint(x: 220, y: numeric.metrics.stripArea + pitch / 2)
            XCTAssertEqual(numeric.hitTest(firstRowPoint)?.row, 0)
            let englishBody = english.keys.filter { (0..<3).contains($0.row) }
            let numericBody = numeric.keys.filter { (0..<3).contains($0.row) }
            XCTAssertEqual(englishBody.map(\.kind), numericBody.map(\.kind))
            for (expected, actual) in zip(englishBody, numericBody) {
                assertSameRect(actual.frame, expected.frame, actual.label)
                // The low part of the punctuation row follows each layout's own footer.
                var expectedHit = expected.hitFrame
                if actual.row == numeric.bottomRowIndex - 1 { expectedHit.size.height = actual.hitFrame.height }
                assertSameRect(actual.hitFrame, expectedHit, actual.label)
            }
        }
        let symbols = KeyboardLayout(width: 440, layer: .symbols, language: .khmer, letters: .khmerism, phoneSize: .large)
        XCTAssertEqual(symbols.keys.filter { $0.row == 3 }.compactMap(\.alternate), ["៙", "៚"])
    }

    func testKhmerismUsesTheSharedNumberRowOnEveryPage() throws {
        for layer in layers {
            let enabled = KeyboardLayout(
                width: 440, layer: layer, language: .khmer, letters: .khmerism, phoneSize: .large, numberRow: true
            )
            let disabled = KeyboardLayout(width: 440, layer: layer, language: .khmer, letters: .khmerism, phoneSize: .large)
            let english = KeyboardLayout(width: 440, layer: layer, phoneSize: .large, numberRow: true)
            let pitch = english.metrics.numberRowPitch
            let digits = enabled.keys.filter(\.isNumberRow)
            XCTAssertTrue(enabled.hasNumberRow)
            XCTAssertEqual(enabled.totalHeight - disabled.totalHeight, pitch, accuracy: 0.001)
            XCTAssertEqual(digits.map(\.label), english.keys.filter(\.isNumberRow).map(\.label))
            for (actual, expected) in zip(digits, english.keys.filter(\.isNumberRow)) {
                assertSameRect(actual.frame, expected.frame, actual.label)
                assertSameRect(actual.hitFrame, expected.hitFrame, actual.label)
            }

            let firstCharacter = try XCTUnwrap(enabled.keys.first { $0.row == 0 && $0.character != nil })
            let original = try XCTUnwrap(disabled.key(firstCharacter.kind))
            assertSameRect(firstCharacter.frame, original.frame.offsetBy(dx: 0, dy: pitch), "\(layer)")
            if layer == .numbers {
                XCTAssertTrue(digits.isEmpty)
                let reservedBand = CGPoint(x: firstCharacter.frame.midX, y: enabled.metrics.stripArea + pitch / 2)
                XCTAssertEqual(enabled.hitTest(reservedBand)?.kind, .character("1"))
            }
        }

        let pad = KeyboardLayout(width: 744, language: .khmer, letters: .khmerism, pad: .docked(.mini), numberRow: true)
        XCTAssertFalse(pad.hasNumberRow)
    }

    func testKhmerismKeepsTheEmojiHitTargetInsideItsCap() throws {
        for layer in layers {
            let layout = KeyboardLayout(
                width: 440, layer: layer, showsEmoji: true, language: .khmer, letters: .khmerism, phoneSize: .large
            )
            let emoji = try XCTUnwrap(layout.key(.emoji))
            XCTAssertEqual(layout.hitTest(CGPoint(x: emoji.frame.midX, y: emoji.frame.midY))?.kind, .emoji)
            for point in [
                CGPoint(x: emoji.frame.minX + 1, y: emoji.frame.midY),
                CGPoint(x: emoji.frame.maxX - 1, y: emoji.frame.midY),
                CGPoint(x: emoji.frame.midX, y: emoji.frame.minY + 1),
            ] {
                XCTAssertNil(layout.hitTest(point))
            }
        }
    }

    @MainActor
    func testKhmerismColorsKhmerDigitsAndLeavesArabicDigitsNeutral() {
        for isDark in [false, true] {
            for digit in "០១២៣៤៥៦៧៨៩" {
                XCTAssertNotNil(KhmerismAppearance.face(for: String(digit), isDark: isDark))
            }
            for digit in KeyboardLayout.numberRowDigits {
                XCTAssertNil(KhmerismAppearance.face(for: digit, isDark: isDark))
            }
        }
    }

    @MainActor
    func testKhmerismLegendsFitWithSpaceBetweenMainAndCorner() throws {
        for (width, phoneSize) in [(420.0, KeyboardPhoneSize.large), (375, .homeButton), (320, .homeButton)] {
            for layer in layers {
                let layout = KeyboardLayout(
                    width: width, layer: layer, showsEmoji: true, language: .khmer, letters: .khmerism, phoneSize: phoneSize
                )
                for key in layout.keys where key.character != nil {
                    let labels = [(key.label, key.alternate), (key.shifted ?? key.label, key.shiftedAlternate)]
                    let safeFrame = key.frame.insetBy(dx: 2, dy: 2)
                    for (main, alternate) in labels {
                        let legends = KhmerismAppearance.legends(
                            main: main, alternate: alternate, in: key.frame, mainSize: 21, ink: .black
                        )
                        let primary = try XCTUnwrap(legends.main, "\(width) \(layer) \(main)")
                        XCTAssertTrue(safeFrame.contains(primary.bounds), "\(width) \(layer) \(main)")
                        if let alternate {
                            let corner = try XCTUnwrap(legends.alternate, alternate)
                            XCTAssertTrue(safeFrame.contains(corner.bounds), alternate)
                            XCTAssertGreaterThanOrEqual(primary.bounds.minY - corner.bounds.maxY, 1.99, "\(main) / \(alternate)")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testKhmerismRequestsAHostResizeWhenItsRowCountChanges() {
        let target = FixtureTextTarget()
        let view = FullKeyboardView(model: KeyboardViewModel(), target: target)
        view.languageOverride = .khmer
        view.letterLayoutOverride = .khmerism
        let fiveRowHeight = view.preferredHeight
        view.frame = CGRect(x: 0, y: 0, width: 393, height: fiveRowHeight)
        view.layoutIfNeeded()
        let fourRowHeight = KeyboardLayout.height(for: .portrait, language: .khmer, layer: .numbers, letters: .khmerism)
        var requested: [CGFloat] = []
        view.onPreferredHeightChange = { [weak view] in
            guard let view else { return }
            requested.append(view.preferredHeight)
            view.frame.size.height = view.preferredHeight
            view.layoutIfNeeded()
        }
        for (id, layer) in [KeyboardLayer.numbers, .symbols, .letters].enumerated() {
            let heightBefore = view.bounds.height
            let frame = view.engine.layout.key(.layerSwitch(layer))!.frame
            let point = CGPoint(x: frame.midX, y: frame.midY)
            view.engine.touchBegan(id: id, at: point)
            // The host grows or shrinks upward, so the same point on screen is offset in the view.
            view.engine.touchEnded(id: id, at: CGPoint(x: point.x, y: point.y + view.bounds.height - heightBefore))
            XCTAssertEqual(view.engine.layout.layer, layer)
        }
        XCTAssertEqual(requested, [fourRowHeight, fiveRowHeight])
        XCTAssertEqual(target.text, "")

        let page = view.engine.layout.key(.layerSwitch(.numbers))!.frame
        view.engine.touchBegan(id: 3, at: CGPoint(x: page.midX, y: page.midY))
        let digit = view.engine.layout.key(.character("1"))!.frame
        let digitCenter = CGPoint(x: digit.midX, y: digit.midY)
        view.engine.touchMoved(id: 3, to: digitCenter)
        XCTAssertEqual(view.engine.previewKey?.character, "1")
        view.engine.touchEnded(id: 3, at: digitCenter)
        XCTAssertEqual(target.text, "1")
        XCTAssertEqual(view.engine.layout.layer, .letters)
        XCTAssertEqual(requested, [fourRowHeight, fiveRowHeight, fourRowHeight, fiveRowHeight])
    }

    func testKhmerismFitsFiveRowsIntoAShorterView() {
        let full = KeyboardLayout(width: 375, language: .khmer, letters: .khmerism, phoneSize: .homeButton)
        let height = full.totalHeight - 30
        let short = KeyboardLayout(width: 375, language: .khmer, letters: .khmerism, phoneSize: .homeButton, availableHeight: height)
        XCTAssertEqual(short.totalHeight, height, accuracy: 0.001)
        XCTAssertEqual(full.stripFrame.height, KeyboardMetrics.appleBarHeight)
        XCTAssertEqual(short.stripFrame.height, KeyboardMetrics.stripBarHeight)
        XCTAssertEqual(short.key(.space)?.hitFrame.maxY ?? 0, height, accuracy: 0.001)
        XCTAssertEqual(short.bottomRowIndex, 4)
        XCTAssertEqual(short.keys.map(\.kind), full.keys.map(\.kind))
        XCTAssertTrue(short.keys.allSatisfy { $0.frame.maxY < height })
    }
}
