import CoreGraphics

extension KeyboardLayout {
    /// A letter key's width on a 10-key row. Shift, delete and the bottom row are sized
    /// from it in every language, as Apple's are.
    var letterWidth: CGFloat {
        if isSplit { return SplitGeometry.keyWidth }
        if let padLetterWidth { return padLetterWidth }
        return Self.letterWidth(innerWidth: width - 2 * horizontalInset, metrics: metrics)
    }

    /// The width of this page's character keys: `letterWidth`, or narrower where a row
    /// holds 11 keys (Norwegian letters).
    var characterWidth: CGFloat {
        if isSplit { return SplitGeometry.keyWidth }
        if let padLetterWidth { return padLetterWidth }
        if language == .khmer, layer == .letters {
            let columns = letters == .khmerism ? 11 : 12
            return Self.letterWidth(innerWidth: width - 2 * horizontalInset, metrics: metrics, columns: columns)
        }
        if hasDvorakPunctuationRow { return letterWidth }
        if layer == .letters, letters == .dvorak {
            return Self.dvorakLetterWidth(innerWidth: width - 2 * horizontalInset, metrics: metrics)
        }
        return Self.letterWidth(
            innerWidth: width - 2 * horizontalInset,
            metrics: metrics,
            columns: Self.columns(Self.characterRows(for: layer, language: language, letters: letters))
        )
    }

    static func letterWidth(innerWidth: CGFloat, metrics: KeyboardMetrics, columns: Int = 10) -> CGFloat {
        (innerWidth - 2 * metrics.side - CGFloat(columns - 1) * metrics.gap) / CGFloat(columns)
    }

    /// Dvorak's letter keys: narrower than a 10-key row's, so shift and nine letters fill row 3
    /// edge to edge, as on Apple's (iOS 27.0 simulator: a 38.3 pt pitch where QWERTY's is 39.5 pt
    /// on a 402 pt iPhone).
    static func dvorakLetterWidth(innerWidth: CGFloat, metrics: KeyboardMetrics) -> CGFloat {
        let modifier = modifierWidth(letterWidth: letterWidth(innerWidth: innerWidth, metrics: metrics), gap: metrics.gap, metrics: metrics)
        return (innerWidth - 2 * metrics.side - modifier) / 9 - metrics.gap
    }

    /// Keys across the widest of rows 1 and 2, never fewer than 10.
    static func columns(_ rows: [[String]]) -> Int {
        max(10, rows.prefix(2).map(\.count).max() ?? 10)
    }

    /// Four rows of Khmer letters plus the layout's weighted footer on every page.
    static func addKhmerRows(
        width: CGFloat,
        metrics: KeyboardMetrics,
        layer: KeyboardLayer,
        field: KeyboardFieldKind,
        inset: CGFloat,
        showsGlobe: Bool,
        showsEmoji: Bool,
        hexPlacement: HexKeyPlacement,
        letters: KeyboardLetterLayout,
        add: (KeyKind, Int, CGFloat, CGFloat, String, KhmerLayout.Key?) -> Void
    ) {
        typealias Entry = (kind: KeyKind, label: String, weight: CGFloat, character: KhmerLayout.Key?)

        let left = inset + metrics.side
        let right = width - left
        let gap = metrics.gap
        let footerRow = metrics.keyRowCount - 1
        let isKhmerism = letters == .khmerism
        let isDocked = metrics.pad?.isDocked == true

        func character(_ key: KhmerLayout.Key) -> Entry {
            (.character(key.text), key.text, 100, key)
        }

        func addRow(_ entries: [Entry], row: Int) {
            let weight = entries.reduce(CGFloat.zero) { $0 + $1.weight }
            let unit = max(0, right - left - CGFloat(entries.count - 1) * gap) / weight
            var x = left
            for entry in entries {
                let width = unit * entry.weight
                add(entry.kind, row, x, width, entry.label, entry.character)
                x += width + gap
            }
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
                addRow(entries, row: row)
            }
        }

        let khmerismFooter = switch layer {
        case .letters: KhmerismLayout.base.last ?? []
        case .numbers: KhmerismLayout.numbersFooter
        case .symbols: KhmerismLayout.symbolsFooter
        }
        let footerCharacters = isKhmerism ? khmerismFooter : []
        let hasFooterGlobe = showsGlobe && !isKhmerism
        let globe: Entry = (.globe, "globe", 114, nil)
        let emoji: Entry = (.emoji, "emoji", 114, nil)
        let hex: Entry = (.hex, "hex", 114, nil)
        var footer: [Entry] = []
        if hasFooterGlobe && isDocked { footer.append(globe) }
        footer.append(layer == .letters
            ? (.layerSwitch(.numbers), "123", 151, nil)
            : (.layerSwitch(.letters), isKhmerism ? "កខគ" : "ក", 151, nil))
        if hasFooterGlobe && !isDocked { footer.append(globe) }
        if showsEmoji && (isKhmerism || !isDocked) { footer.append(emoji) }
        if hexPlacement == .leftOfSpace { footer.append(hex) }
        footer.append((.space, "ខ្មែរ", 507, nil))
        for (index, key) in footerCharacters.enumerated() {
            var entry = character(key)
            if index == 0 { entry.weight = 101 }
            footer.append(entry)
        }
        for (kind, weight, label) in field.keysRightOfSpace(width: 100) {
            footer.append((kind, label, weight, nil))
        }
        if hexPlacement == .rightOfSpace { footer.append(hex) }
        footer.append((.returnKey, "↵", 221, nil))
        if isDocked {
            if showsEmoji && !isKhmerism { footer.append(emoji) }
            footer.append((.dismiss, "dismiss", 100, nil))
        }
        addRow(footer, row: footerRow)
    }

    /// Tile a joined key plane after its letter, symbol and footer caps have been positioned.
    static func joinedHitTargets(
        for drawn: [KeyboardKey], width: CGFloat, metrics m: KeyboardMetrics,
        numberRow: Bool
    ) -> [KeyboardKey] {
        let footerRow = m.keyRowCount - 1
        // Touch targets: split every gap down the middle; outer keys reach the edges, and row 1
        // the gap under the strip (or the strip's bottom band).
        let top = m.stripArea - max(m.stripBottom, stripTouchBand)
        let bottom = m.totalHeight
        var keys: [KeyboardKey] = []
        // The gap above the space bar is the space bar's, as Apple's (iOS 27.2) is: row 3's keys over it
        // end at their keycaps. Elsewhere gaps split, so a low m over return stays m (Ryan's taps).
        let spaceKeycap = m.pad == nil ? drawn.first { $0.kind == .space && $0.row == footerRow }?.frame : nil
        var spaceBand: (CGFloat, CGFloat)?
        for row in (numberRow ? [numberRowIndex] : []) + Array(0...footerRow) {
            let rowKeys = drawn.filter { $0.row == row }.sorted { $0.frame.minX < $1.frame.minX }
            let y0 = row == numberRowIndex || (row == 0 && !numberRow) ? top : m.rowY(row) - m.rowGap / 2
            let y1 = row == footerRow ? bottom : m.rowY(row == numberRowIndex ? 0 : row + 1) - m.rowGap / 2
            for (i, item) in rowKeys.enumerated() {
                let x0 = i == 0 ? 0 : (rowKeys[i - 1].frame.maxX + item.frame.minX) / 2
                let x1 = i == rowKeys.count - 1 ? width : (item.frame.maxX + rowKeys[i + 1].frame.minX) / 2
                var hit = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
                if row == footerRow - 1, let space = spaceKeycap, item.frame.midX > space.minX, item.frame.midX < space.maxX {
                    hit.size.height = item.frame.maxY - y0
                    spaceBand = (min(spaceBand?.0 ?? x0, x0), max(spaceBand?.1 ?? x1, x1))
                }
                if item.kind == .emoji, row == footerRow, m.keyHeight >= 40 {
                    // Apple's emoji key takes taps only well inside its keycap, 6 pt in from each
                    // side and 7.5 pt below its top, and the margins around it type nothing:
                    // a finger aimed at 123 or space that lands near it doesn't switch keyboards.
                    hit = CGRect(x: item.frame.minX + 6, y: item.frame.minY + 7.5, width: item.frame.width - 12, height: y1 - item.frame.minY - 7.5)
                }
                var key = item
                key.hitFrame = hit
                if item.kind == .space, row == footerRow, let band = spaceBand {
                    key.gapHitFrame = CGRect(x: band.0, y: m.rowY(footerRow) - m.rowGap, width: band.1 - band.0, height: m.rowGap / 2)
                }
                keys.append(key)
            }
        }
        return keys
    }

    /// Hex and the optional Khmerism Globe share the joined strip's icon geometry.
    static func joinedStripKey(
        _ kind: KeyKind, width: CGFloat, inset: CGFloat, metrics m: KeyboardMetrics, leading: Bool
    ) -> KeyboardKey {
        let height = m.appleBar ? KeyboardMetrics.barHexKeyHeight : m.stripPillHeight
        let hexWidth: CGFloat = 44
        let cell = KeyboardMetrics.appleIconCellWidth
        let left = inset + m.side
        let right = width - inset - m.side
        let x = m.appleBar
            ? (leading ? inset + (cell - hexWidth) / 2 : width - inset - (cell + hexWidth) / 2)
            : (leading ? left : right - hexWidth)
        let y = m.appleBar ? m.stripTop + m.stripTextCenter - height / 2 : m.stripTop + m.stripInset
        let frame = CGRect(x: x, y: y, width: hexWidth, height: height)
        // In Apple's bar the key takes its whole cell across, up to the slot beside it.
        let target = m.appleBar
            ? CGRect(x: x - (cell - hexWidth) / 2, y: frame.minY - 4, width: cell, height: frame.height + 8)
            : frame.insetBy(dx: -4, dy: -4)
        let targetTop = min(target.minY, m.stripTop)
        let keysTop = m.stripArea - max(m.stripBottom, stripTouchBand)
        let hitFrame = CGRect(x: target.minX, y: targetTop, width: target.width, height: keysTop - targetTop)
        return KeyboardKey(kind: kind, row: -1, frame: frame, hitFrame: hitFrame, label: kind == .globe ? "globe" : "hex")
    }
}
