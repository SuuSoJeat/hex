import CoreGraphics

extension KeyboardLayout {
    /// The split keyboard: each row's halves at the keyboard's sides with Apple's key sizes,
    /// row 2 in half a key from the side and row 3's letters a key and a half, two space bars,
    /// and touch targets that tile each half but leave the middle to no key.
    static func buildSplitKeys(
        width: CGFloat,
        metrics m: KeyboardMetrics,
        layer: KeyboardLayer,
        field: KeyboardFieldKind,
        showsGlobe: Bool,
        showsEmoji: Bool,
        inset: CGFloat,
        language: KeyboardLanguage,
        letters: KeyboardLetterLayout = .own,
        hexPlacement placement: HexKeyPlacement,
        dvorakPunctuation: Bool = false,
        commaPeriodKeys: Bool = false
    ) -> (keys: [KeyboardKey], split: SplitGeometry) {
        typealias G = SplitGeometry
        // Dvorak splits like the other layouts, delete ending row 3 (Apple's split Dvorak unobserved).
        let khmerLetters = letters == .khmer && layer == .letters ? KhmerLayout.letters : []
        let rows = khmerLetters.isEmpty ? characterRows(for: layer, language: language, letters: letters)
            : khmerLetters.map { $0.map(\.text) }
        let footerRow = m.keyRowCount - 1
        let modifierRow = footerRow - 1
        // Settings › Experiments › Dvorak punctuation, as on the joined keyboard: a URL, email or
        // web search field keeps its own `.` key, so its row 1 stays Apple's.
        let punctuation = layer == .letters && letters == .dvorak && dvorakPunctuation
        let punctuationRow = punctuation && field == .text
        let left = inset + m.side
        let right = width - inset - m.side
        let p = G.pitch

        func rowY(_ row: Int) -> CGFloat {
            if row == numberRowIndex { return m.stripArea + m.keysTop }
            return m.stripArea + m.keysTop + m.numberRowPitch + CGFloat(row) * (m.keyHeight + m.rowGap)
        }
        var drawn: [(kind: KeyKind, row: Int, frame: CGRect, label: String, rightHalf: Bool, shifted: String?)] = []
        func add(_ kind: KeyKind, row: Int, x: CGFloat, w: CGFloat, label: String, rightHalf: Bool, shifted: String? = nil) {
            let h = row == numberRowIndex ? m.numberRowHeight : m.keyHeight
            drawn.append((kind, row, CGRect(x: x, y: rowY(row), width: w, height: h), label, rightHalf, shifted))
        }
        func addRow(_ chars: [String], row: Int, leftStart: CGFloat, rightEnd: CGFloat) -> (CGFloat, CGFloat) {
            let (l, r) = G.halves(chars)
            let variants = khmerLetters.indices.contains(row) ? khmerLetters[row] : []
            func shifted(_ character: String) -> String? { variants.first { $0.text == character }?.shifted }
            for (i, ch) in l.enumerated() {
                add(.character(ch), row: row, x: leftStart + CGFloat(i) * p, w: G.keyWidth, label: ch, rightHalf: false, shifted: shifted(ch))
            }
            let rStart = rightEnd - CGFloat(r.count) * p + G.gap
            for (i, ch) in r.enumerated() {
                add(.character(ch), row: row, x: rStart + CGFloat(i) * p, w: G.keyWidth, label: ch, rightHalf: true, shifted: shifted(ch))
            }
            return (leftStart + CGFloat(l.count) * p - G.gap, rStart)
        }

        // The number row: 1 to 5 and 6 to 0 over row 1's halves.
        let numberRow = drawsNumberRow(m, layer: layer)
        if numberRow {
            _ = addRow(numberRowDigits, row: numberRowIndex, leftStart: left, rightEnd: right)
        }

        // Rows 1 and 2: row 2 sits half a key in from each side. With the experiment, comma and
        // period join row 1's left half on a pitch narrowed so that half keeps its right edge,
        // and the right half stays exactly where it was: the split gap doesn't move.
        let leftEdge: CGFloat
        let rightEdge: CGFloat
        if punctuationRow {
            let (leftChars, rightChars) = G.halves(rows[0])
            let edge = left + CGFloat(leftChars.count) * p - G.gap
            // The half keeps its keys, g on both halves included, and the two punctuation keys
            // take their room from the pitch.
            let chars = [",", "."] + leftChars
            let rowWidth = min(G.keyWidth, (edge - left + G.gap) / CGFloat(chars.count) - G.gap)
            let shifted = [",": "<", ".": ">"]
            for (i, ch) in chars.enumerated() {
                add(.character(ch), row: 0, x: left + CGFloat(i) * (rowWidth + G.gap), w: rowWidth, label: ch, rightHalf: false, shifted: shifted[ch])
            }
            let start = right - CGFloat(rightChars.count) * p + G.gap
            for (i, ch) in rightChars.enumerated() {
                add(.character(ch), row: 0, x: start + CGFloat(i) * p, w: G.keyWidth, label: ch, rightHalf: true)
            }
            leftEdge = edge
            rightEdge = start
        } else {
            let edges = addRow(rows[0], row: 0, leftStart: left, rightEnd: right)
            leftEdge = edges.0
            rightEdge = edges.1
        }
        for row in 1..<modifierRow {
            _ = addRow(rows[row], row: row, leftStart: left + p / 2, rightEnd: right - p / 2)
        }

        // The last character row: shift (or the page switch) and delete at the sides, keys a key and a
        // half in from each side.
        switch layer {
        case .letters: add(.shift, row: modifierRow, x: left, w: G.modifierWidth, label: "shift", rightHalf: false)
        case .numbers: add(.layerSwitch(.symbols), row: modifierRow, x: left, w: G.modifierWidth, label: "#+=", rightHalf: false)
        case .symbols: add(.layerSwitch(.numbers), row: modifierRow, x: left, w: G.modifierWidth, label: "123", rightHalf: false)
        }
        _ = addRow(rows[modifierRow], row: modifierRow, leftStart: left + 1.5 * p, rightEnd: right - 1.5 * p)
        add(.delete, row: modifierRow, x: right - G.modifierWidth, w: G.modifierWidth, label: "delete", rightHalf: true)

        // Footer: 123/ABC, globe?, emoji? and a space bar on the left; a space bar, the field's
        // extras, Hex (when it sits in the row) and return on the right.
        var x = left
        let switchKind: KeyKind = layer == .letters ? .layerSwitch(.numbers) : .layerSwitch(.letters)
        let switchLabel = layer == .letters ? "123" : (letters == .khmer ? "ក" : "ABC")
        let spaceLabel = letters == .khmer ? "ខ្មែរ" : "space"
        add(switchKind, row: footerRow, x: x, w: G.layerSwitchWidth, label: switchLabel, rightHalf: false)
        x += G.layerSwitchWidth + G.gap
        if showsGlobe {
            add(.globe, row: footerRow, x: x, w: G.smallKeyWidth, label: "globe", rightHalf: false)
            x += G.smallKeyWidth + G.gap
        }
        if showsEmoji {
            add(.emoji, row: footerRow, x: x, w: G.smallKeyWidth, label: "emoji", rightHalf: false)
            x += G.smallKeyWidth + G.gap
        }
        // With the experiment, a semicolon sits just before the left space bar, which keeps
        // ending where it did, where the bar holds a key and a space besides.
        var leftSpaceW = max(G.keyWidth, leftEdge - x)
        if punctuation, leftSpaceW >= 2 * G.keyWidth + G.gap {
            add(.character(";"), row: footerRow, x: x, w: G.keyWidth, label: ";", rightHalf: false, shifted: ":")
            x += G.keyWidth + G.gap
            leftSpaceW -= G.keyWidth + G.gap
        }
        add(.space, row: footerRow, x: x, w: leftSpaceW, label: spaceLabel, rightHalf: false)

        var trailing = field.keysRightOfSpace(width: G.smallKeyWidth)
        if !placement.isInStrip {
            trailing.append((.hex, G.smallKeyWidth, "hex"))
        }
        trailing.append((.returnKey, G.returnWidth, "return"))
        let trailingWidth = trailing.reduce(0) { $0 + $1.1 + G.gap }
        let spaceRightWidth = max(G.keyWidth, right - rightEdge - trailingWidth)
        add(.space, row: footerRow, x: rightEdge, w: spaceRightWidth, label: spaceLabel, rightHalf: true)
        x = rightEdge + spaceRightWidth + G.gap
        for (kind, w, label) in trailing {
            add(kind, row: footerRow, x: x, w: w, label: label, rightHalf: true)
            x += w + G.gap
        }

        // Settings › Experiments › Comma and period keys: a comma just left of the left half's
        // space bar and a period just right of the right half's, taking their width from the
        // bars, where each still holds a letter-wide key and a space besides it.
        if commaPeriodKeys {
            Self.addSplitCommaPeriodKeys(to: &drawn, keyWidth: G.keyWidth, gap: G.gap, footerRow: footerRow)
        }

        // Touch targets: each half tiles from its side to half a gap past its inner key; the
        // middle between the halves is no key's.
        let top = m.stripArea - max(m.stripBottom, stripTouchBand)
        var keys: [KeyboardKey] = []
        for row in (numberRow ? [numberRowIndex] : []) + Array(0...footerRow) {
            let y0 = row == numberRowIndex || (row == 0 && !numberRow) ? top : rowY(row) - m.rowGap / 2
            let y1 = row == footerRow ? m.totalHeight : rowY(row == numberRowIndex ? 0 : row + 1) - m.rowGap / 2
            for half in [false, true] {
                let items = drawn.filter { $0.row == row && $0.rightHalf == half }.sorted { $0.frame.minX < $1.frame.minX }
                for (i, item) in items.enumerated() {
                    let x0 = i == 0 ? (half ? item.frame.minX - G.gap / 2 : 0) : (items[i - 1].frame.maxX + item.frame.minX) / 2
                    let x1 = i == items.count - 1 ? (half ? width : item.frame.maxX + G.gap / 2) : (item.frame.maxX + items[i + 1].frame.minX) / 2
                    keys.append(KeyboardKey(
                        kind: item.kind,
                        row: row,
                        frame: item.frame,
                        hitFrame: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                        label: item.label,
                        shifted: item.shifted
                    ))
                }
            }
        }
        if placement.isInStrip {
            let height = m.stripPillHeight
            let hexWidth: CGFloat = 44
            let hx = placement == .stripLeading ? left : right - hexWidth
            let frame = CGRect(x: hx, y: m.stripTop + m.stripInset, width: hexWidth, height: height)
            let target = frame.insetBy(dx: -4, dy: -4)
            let hitFrame = CGRect(x: target.minX, y: target.minY, width: target.width, height: top - target.minY)
            keys.append(KeyboardKey(kind: .hex, row: -1, frame: frame, hitFrame: hitFrame, label: "hex"))
        }
        return (keys, SplitGeometry(leftEdge: leftEdge, rightEdge: rightEdge))
    }
}
