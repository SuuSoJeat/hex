import CoreGraphics

extension KeyboardLayout {
    /// Preserve the designer's grid and footer. Place native keyboard controls in the strip
    /// where possible so they do not change the approved portrait proportions.
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
        case .emoji: KhmerismLayout.emoji
        }
        func character(_ key: KhmerismLayout.Key) -> Entry {
            (.character(key.text), key.text, 1, key)
        }
        var rows = characters.map { $0.map(character) }
        let switchKey: Entry = switch layer {
        case .letters, .emoji: (.shift, "⇧", 1, nil)
        case .numbers: (.layerSwitch(.symbols), "#+=", 1, nil)
        case .symbols: (.layerSwitch(.numbers), "123", 1, nil)
        }
        rows[3].insert(switchKey, at: 0)
        rows[3].append((.delete, "⌫", 1, nil))

        let bottom = rows.count - 1
        let hasNumericPage = layer == .numbers || layer == .symbols
        var footer: [Entry] = [
            hasNumericPage ? (.layerSwitch(.letters), "ខ្មែរ", 1.35, nil) : (.layerSwitch(.numbers), "123", 1.35, nil),
            (.layerSwitch(.letters), "ខ្មែរ", 1.15, nil),
        ]
        if showsEmoji || layer == .emoji {
            footer.append(layer == .emoji ? (.layerSwitch(.letters), "ខ្មែរ", 1.05, nil) : (.layerSwitch(.emoji), "☺", 1.05, nil))
        }
        footer.append((.space, "ដកឃ្លា", 2.9, nil))
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
        footer.append((.returnKey, "↵", 1.65, nil))
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
            let gap = metrics.gap
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
        func addStripKey(_ kind: KeyKind, label: String, leading: Bool) {
            let span: CGFloat = 44
            let height: CGFloat = 24
            let frame = CGRect(
                x: leading ? left : right - span, y: metrics.stripTop + metrics.stripTextCenter - height / 2,
                width: span, height: height
            )
            let target = frame.insetBy(dx: -4, dy: 0)
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
