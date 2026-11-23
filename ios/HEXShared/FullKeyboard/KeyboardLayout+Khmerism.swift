import CoreGraphics

extension KeyboardLayout {
    /// The Khmer layouts use their own letter pages and share the same strip and touch geometry.
    static func buildKhmerKeys(
        width: CGFloat,
        metrics: KeyboardMetrics,
        layer: KeyboardLayer,
        field: KeyboardFieldKind,
        inset: CGFloat,
        showsGlobe: Bool,
        showsEmoji: Bool,
        hexPlacement: HexKeyPlacement,
        letters: KeyboardLetterLayout
    ) -> [KeyboardKey] {
        typealias Entry = (kind: KeyKind, label: String, weight: CGFloat, character: KhmerismLayout.Key?)
        typealias Cap = (entry: Entry, x: CGFloat, width: CGFloat)

        let innerWidth = width - 2 * inset
        let left = inset + metrics.side
        let right = width - left
        let gap = metrics.gap
        let pitch = metrics.keyHeight + metrics.rowGap
        let footerRow = metrics.keyRowCount - 1
        let touchTop = metrics.stripArea - max(metrics.stripBottom, stripTouchBand)
        let firstY = metrics.stripArea + metrics.keysTop
        let numberRow = drawsNumberRow(metrics, layer: layer)
        let isKhmerism = letters == .khmerism
        var keys: [KeyboardKey] = []

        func character(_ key: KhmerismLayout.Key) -> Entry {
            (.character(key.text), key.text, 100, key)
        }

        func weightedCaps(_ entries: [Entry]) -> [Cap] {
            let weight = entries.reduce(CGFloat.zero) { $0 + $1.weight }
            let unit = max(0, right - left - CGFloat(entries.count - 1) * gap) / weight
            var x = left
            return entries.map { entry in
                let width = unit * entry.weight
                defer { x += width + gap }
                return (entry, x, width)
            }
        }

        func rowY(_ row: Int) -> CGFloat {
            if row == numberRowIndex { return firstY }
            return firstY + metrics.numberRowPitch + CGFloat(row) * pitch
        }

        func addRow(_ caps: [Cap], row: Int) {
            let y = rowY(row)
            let height = row == footerRow ? metrics.bottomRowHeight : row == numberRowIndex ? metrics.numberRowHeight : metrics.keyHeight
            let hitTop = row == numberRowIndex || (row == 0 && !numberRow) ? touchTop : y - metrics.rowGap / 2
            let nextRow = row == numberRowIndex ? 0 : row + 1
            let hitBottom = row == footerRow ? metrics.totalHeight : rowY(nextRow) - metrics.rowGap / 2
            for (index, cap) in caps.enumerated() {
                let frame = CGRect(x: cap.x, y: y, width: cap.width, height: height)
                let hitLeft: CGFloat
                if index == 0 {
                    hitLeft = 0
                } else {
                    let previous = caps[index - 1]
                    hitLeft = (previous.x + previous.width + frame.minX) / 2
                }
                let hitRight = index == caps.count - 1 ? width : (frame.maxX + caps[index + 1].x) / 2
                let entry = cap.entry
                var hitFrame = CGRect(x: hitLeft, y: hitTop, width: hitRight - hitLeft, height: hitBottom - hitTop)
                if entry.kind == .emoji, row == footerRow, metrics.keyHeight >= 40 {
                    hitFrame = emojiHitFrame(for: frame, rowBottom: hitBottom)
                }
                keys.append(KeyboardKey(
                    kind: entry.kind, row: row, frame: frame,
                    hitFrame: hitFrame,
                    label: entry.label, shifted: entry.character?.shifted,
                    alternate: entry.character?.alternate, shiftedAlternate: entry.character?.shiftedAlternate
                ))
            }
        }

        if numberRow {
            addRow(weightedCaps(numberRowDigits.map { character(.init(text: $0)) }), row: numberRowIndex)
        }

        let delete: Entry = (.delete, "delete", 100, nil)
        if layer == .letters {
            let rows = isKhmerism ? Array(KhmerismLayout.base.dropLast()) : KhmerLayout.letters
            for (row, characters) in rows.enumerated() {
                var entries = characters.map(character)
                if row == footerRow - 1 {
                    entries.insert((.shift, "shift", 100, nil), at: 0)
                    entries.append(delete)
                }
                addRow(weightedCaps(entries), row: row)
            }
        } else {
            let rows = characterRows(for: layer, language: .khmer, letters: letters)
            for (index, letters) in rows.dropLast().enumerated() {
                addRow(weightedCaps(letters.map { character(.init(text: $0)) }), row: index)
            }
            let punctuation = rows[2].map { character(.init(text: $0)) }
            let letter = letterWidth(innerWidth: innerWidth, metrics: metrics)
            let modifier = modifierWidth(letterWidth: letter, gap: gap, metrics: metrics)
            let middle = numericPunctuationGeometry(innerWidth: innerWidth, letterWidth: letter, metrics: metrics, count: punctuation.count)
            let toggle: Entry = layer == .numbers
                ? (.layerSwitch(.symbols), "#+=", 100, nil)
                : (.layerSwitch(.numbers), "123", 100, nil)
            var caps: [Cap] = [(toggle, left, modifier)]
            for (index, entry) in punctuation.enumerated() {
                caps.append((entry, left + middle.inset + CGFloat(index) * (middle.width + gap), middle.width))
            }
            caps.append((delete, right - modifier, modifier))
            addRow(caps, row: footerRow - 1)
        }

        let khmerismFooter = switch layer {
        case .letters: KhmerismLayout.base.last ?? []
        case .numbers: KhmerismLayout.numbersFooter
        case .symbols: KhmerismLayout.symbolsFooter
        }
        let footerCharacters = isKhmerism ? khmerismFooter : []
        var footer: [Entry] = [layer == .letters
            ? (.layerSwitch(.numbers), "123", 151, nil)
            : (.layerSwitch(.letters), isKhmerism ? "កខគ" : "ក", 151, nil)]
        if showsEmoji { footer.append((.emoji, "emoji", 114, nil)) }
        footer.append((.space, "ខ្មែរ", 507, nil))
        for (index, key) in footerCharacters.enumerated() {
            var entry = character(key)
            if index == 0 { entry.weight = 101 }
            footer.append(entry)
        }
        if isKhmerism {
            switch field {
            case .text: break
            case .webSearch: footer.append(character(.init(text: ".")))
            case .url: footer.append(contentsOf: [character(.init(text: ".")), character(.init(text: "/"))])
            case .email: footer.append(contentsOf: [character(.init(text: "@")), character(.init(text: "."))])
            }
        }
        footer.append((.returnKey, "↵", 221, nil))
        if metrics.pad?.isDocked == true { footer.append((.dismiss, "dismiss", 100, nil)) }
        addRow(weightedCaps(footer), row: footerRow)
        giveSpaceBarItsTopGap(in: &keys, metrics: metrics)

        func addStripKey(_ kind: KeyKind, label: String, leading: Bool) {
            let span: CGFloat = 44
            let cell = KeyboardMetrics.appleIconCellWidth
            let height = metrics.appleBar ? KeyboardMetrics.barHexKeyHeight : metrics.stripPillHeight
            let x = metrics.appleBar
                ? (leading ? inset + (cell - span) / 2 : width - inset - (cell + span) / 2)
                : (leading ? left : right - span)
            let frame = CGRect(
                x: x, y: metrics.stripTop + metrics.stripTextCenter - height / 2,
                width: span, height: height
            )
            let target = frame.insetBy(dx: metrics.appleBar ? -(cell - span) / 2 : -4, dy: 0)
            keys.append(KeyboardKey(
                kind: kind, row: -1, frame: frame,
                hitFrame: CGRect(x: target.minX, y: metrics.stripTop, width: target.width, height: touchTop - metrics.stripTop),
                label: label
            ))
        }
        let hexLeads = hexPlacement == .stripLeading
        addStripKey(.hex, label: "hex", leading: hexLeads)
        if showsGlobe { addStripKey(.globe, label: "globe", leading: !hexLeads) }
        return keys
    }
}
