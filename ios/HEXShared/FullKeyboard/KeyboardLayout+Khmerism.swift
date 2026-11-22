import CoreGraphics

extension KeyboardLayout {
    /// The Khmerism key order is the same on every screen. Use the space around its
    /// regular rows for Hex's field shortcuts, globe, and dictation key.
    static func buildKhmerismKeys(
        width: CGFloat,
        metrics: KeyboardMetrics,
        layer: KeyboardLayer,
        field: KeyboardFieldKind,
        inset: CGFloat,
        showsGlobe: Bool,
        showsEmoji: Bool,
        hexPlacement: HexKeyPlacement
    ) -> [KeyboardKey] {
        typealias Entry = (kind: KeyKind, label: String, weight: CGFloat, character: KhmerismLayout.Key?)
        let characters = switch layer {
        case .letters: KhmerismLayout.base
        case .numbers: KhmerismLayout.numbers
        case .symbols: KhmerismLayout.symbols
        }
        func character(_ key: KhmerismLayout.Key) -> Entry {
            (.character(key.text), key.text, 1, key)
        }
        var rows = characters.map { $0.map(character) }
        let switchKey: Entry = switch layer {
        case .letters: (.shift, "shift", 1, nil)
        case .numbers: (.layerSwitch(.symbols), "#+=", 1, nil)
        case .symbols: (.layerSwitch(.numbers), "123", 1, nil)
        }
        rows[3].insert(switchKey, at: 0)
        rows[3].append((.delete, "delete", 1, nil))

        let bottom = rows.count - 1
        var footer: [Entry] = layer == .letters
            ? [(.layerSwitch(.numbers), "123", 1.05, nil), (.layerSwitch(.letters), "ខ្មែរ", 1.25, nil)]
            : [(.layerSwitch(.letters), "ខ្មែរ", 1.25, nil)]
        if showsGlobe { footer.append((.globe, "globe", 1, nil)) }
        if showsEmoji { footer.append((.emoji, "emoji", 1, nil)) }
        if hexPlacement == .leftOfSpace { footer.append((.hex, "hex", 1, nil)) }
        footer.append((.space, "ដកឃ្លា", 2.5, nil))
        footer.append(contentsOf: rows[bottom])
        switch field {
        case .text: break
        case .url:
            footer.append((.character("."), ".", 1, nil))
            footer.append((.character("/"), "/", 1, nil))
        case .email:
            footer.append((.character("@"), "@", 1, nil))
            footer.append((.character("."), ".", 1, nil))
        }
        if hexPlacement == .rightOfSpace { footer.append((.hex, "hex", 1, nil)) }
        footer.append((.returnKey, "return", 1.4, nil))
        if metrics.pad?.isDocked == true { footer.append((.dismiss, "dismiss", 1, nil)) }
        rows[bottom] = footer

        let left = inset + metrics.side
        let right = width - left
        let touchTop = metrics.stripArea - max(metrics.stripBottom, stripTouchBand)
        let firstY = metrics.stripArea + metrics.keysTop
        let pitch = metrics.keyHeight + metrics.rowGap
        var keys: [KeyboardKey] = []
        for (row, entries) in rows.enumerated() {
            let y = firstY + CGFloat(row) * pitch
            let height = row == bottom ? metrics.bottomRowHeight : metrics.keyHeight
            let hitTop = row == 0 ? touchTop : y - metrics.rowGap / 2
            let hitBottom = row == bottom ? metrics.totalHeight : y + pitch - metrics.rowGap / 2
            // The footer packs more controls than the character rows on a narrow screen.
            let gap = row == bottom && right - left < 400 ? min(metrics.gap, 4) : metrics.gap
            let totalWeight = entries.reduce(CGFloat.zero) { $0 + $1.weight }
            let unit = max(0, right - left - CGFloat(entries.count - 1) * gap) / totalWeight
            var x = left
            for (index, entry) in entries.enumerated() {
                let frame = CGRect(x: x, y: y, width: unit * entry.weight, height: height)
                let hitLeft = index == 0 ? 0 : x - gap / 2
                let hitRight = index == entries.count - 1 ? width : frame.maxX + gap / 2
                keys.append(KeyboardKey(
                    kind: entry.kind, row: row, frame: frame,
                    hitFrame: CGRect(x: hitLeft, y: hitTop, width: hitRight - hitLeft, height: hitBottom - hitTop),
                    label: entry.label, shifted: entry.character?.shifted,
                    alternate: entry.character?.alternate, shiftedAlternate: entry.character?.shiftedAlternate
                ))
                x = frame.maxX + gap
            }
        }
        if hexPlacement.isInStrip {
            let x = hexPlacement == .stripLeading ? left : right - 44
            let frame = CGRect(x: x, y: metrics.stripTop + metrics.stripInset, width: 44, height: metrics.stripPillHeight)
            let target = frame.insetBy(dx: -4, dy: -4)
            let y = min(target.minY, metrics.stripTop)
            keys.append(KeyboardKey(
                kind: .hex, row: -1, frame: frame,
                hitFrame: CGRect(x: target.minX, y: y, width: target.width, height: touchTop - y),
                label: "hex"
            ))
        }
        return keys
    }
}
