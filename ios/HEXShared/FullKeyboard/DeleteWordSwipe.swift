import UIKit

/// Press and hold delete, then slide left: each key width the finger travels left of where it
/// went down deletes one more word, sliding back right types those words back, and lifting the
/// finger keeps what is deleted. Words are what Option-Delete removes on a Mac: the spaces and
/// punctuation before the cursor go with the word in front of them. Only the text proxy is
/// used: each word deleted is remembered so it can be typed back.
@MainActor
final class DeleteWordSwipe {
    let touchID: Int
    private let engine: FullKeyboardEngine
    private let startX: CGFloat
    private let step: CGFloat
    /// What each step deleted, oldest first; a slide back types the last one back.
    private var deleted: [String] = []
    private struct KhmerCaret {
        let document: UUID
        let route: Int
        var before: String
        let after: String
        /// The full prefix after the last restore, until the proxy reports it.
        var restoredBefore: String?
    }
    private var khmerCaret: KhmerCaret?
    private var invalidated = false
    /// Once the finger is a key width left: hold-to-repeat stops and the slide owns delete.
    private(set) var isActive = false

    init(engine: FullKeyboardEngine, touchID: Int, startX: CGFloat) {
        self.engine = engine
        self.touchID = touchID
        self.startX = startX
        step = max(1, engine.layout.letterWidth)
    }

    var deletedWordCount: Int { deleted.count }

    /// The finger moved: delete or restore words until their count matches how far left it
    /// is. True once the slide is active.
    @discardableResult
    func move(to x: CGFloat) -> Bool {
        let wanted = wordsLeft(at: x)
        if !isActive {
            guard wanted > 0 else { return false }
            isActive = true
            engine.typingLog?.ui("delete_swipe_start", [TypingLogField("id", .int(touchID))])
            if engine.layout.language == .khmer {
                let target = engine.target
                if let document = target.documentIdentifier {
                    khmerCaret = KhmerCaret(
                        document: document, route: target.inputRouteRevision,
                        before: target.documentContextBeforeInput ?? "", after: target.documentContextAfterInput ?? ""
                    )
                } else {
                    invalidated = true
                }
            }
        }
        guard engine.khmerDeleteRecovery == nil, canEditAtCaret() else { return true }
        var changed = false
        while deleted.count < wanted, canEditAtCaret(), deleteWord() {
            changed = true
        }
        if deleted.count > wanted, khmerCaret != nil, canEditAtCaret(), var caret = khmerCaret {
            // One move may restore several words before the proxy can report a new caret.
            let text = deleted[wanted...].reversed().joined()
            deleted.removeLast(deleted.count - wanted)
            caret.restoredBefore = caret.before + text
            khmerCaret = caret
            restore(text)
            changed = true
        } else if khmerCaret == nil {
            while deleted.count > wanted, let text = deleted.popLast() {
                restore(text)
                changed = true
            }
        }
        if changed {
            engine.textDidChange()
            engine.onEdit?(.normal)
        }
        return true
    }

    private func wordsLeft(at x: CGFloat) -> Int {
        max(0, Int(((startX - x) / step).rounded(.down)))
    }

    private func canEditAtCaret() -> Bool {
        guard !invalidated else { return false }
        guard var caret = khmerCaret else { return engine.layout.language != .khmer }
        let target = engine.target
        guard engine.layout.language == .khmer,
              target.documentIdentifier == caret.document, target.inputRouteRevision == caret.route,
              (target.selectedText ?? "").isEmpty,
              (target.documentContextAfterInput ?? "").utf16.elementsEqual(caret.after.utf16) else {
            invalidated = true
            return false
        }
        let context = target.documentContextBeforeInput
        let reported = context ?? ""
        let unchanged = reported.utf16.elementsEqual(caret.before.utf16)
        if let expected = caret.restoredBefore {
            // An old echo never authorizes another edit. Wait for the next move to check again.
            if context == nil || unchanged { return false }
            // A capped proxy can drop earlier text as the restored words come into view.
            let fillsWindow = reported.utf16.count >= caret.before.utf16.count || reported.count >= caret.before.count
            if !reported.isEmpty, fillsWindow,
               expected.utf16.suffix(reported.utf16.count).elementsEqual(reported.utf16) {
                caret.before = reported
                caret.restoredBefore = nil
                khmerCaret = caret
                return true
            }
        } else if unchanged {
            return true
        }
        invalidated = true
        return false
    }

    private func restore(_ text: String) {
        engine.commitHangulComposition()
        engine.typingLog?.edit("insert", [
            TypingLogField("inserted", .string(text)),
            TypingLogField("src", .string("delete_swipe_restore")),
        ])
        engine.forgetTextAroundKeys()
        engine.target.insertText(text)
        engine.onSelectionStep?()
    }

    /// A lift can complete a restore the proxy was still reporting when the finger moved.
    /// Cancellation has no final position and leaves the remaining words deleted.
    func finish(at x: CGFloat? = nil) {
        guard isActive else { return }
        if let x, khmerCaret?.restoredBefore != nil, wordsLeft(at: x) < deleted.count {
            move(to: x)
        }
        engine.typingLog?.ui("delete_swipe_end", [
            TypingLogField("id", .int(touchID)),
            TypingLogField("words", .int(deleted.count)),
        ])
        engine.typingLog?.context("delete_swipe")
        deleted.removeAll()
    }

    private func deleteWord() -> Bool {
        // A word delete writes the field directly: it ends any Hangul run first. A finger's
        // jitter before the first word must not, so this is here, not in `move`.
        engine.commitHangulComposition()
        guard let before = engine.target.documentContextBeforeInput else { return false }
        if engine.layout.language == .khmer {
            guard let text = engine.khmerWordToDelete(before: before),
                  case .removed = engine.deleteKhmerWord(text, before: before, source: "delete_swipe") else { return false }
            // The engine has confirmed this deletion against the original raw proxy context.
            khmerCaret?.before = engine.target.documentContextBeforeInput ?? ""
            deleted.append(text)
            engine.onSelectionStep?()
            return true
        }
        guard let count = Self.wordLength(before: before) else { return false }
        let text = String(before.suffix(count))
        engine.typingLog?.edit("delete_word", [
            TypingLogField("deleted", .string(text)),
            TypingLogField("src", .string("delete_swipe")),
        ])
        engine.forgetTextAroundKeys()
        for _ in 0..<count {
            engine.target.deleteBackward()
        }
        deleted.append(text)
        engine.onSelectionStep?()
        return true
    }

    static func splitTrailingSeparators(in before: String) -> (Substring, Substring) {
        var end = before.endIndex
        while end > before.startIndex {
            let previous = before.index(before: end)
            let cluster = before[previous..<end]
            guard !isWordCharacter(before[previous]), !KhmerAutocomplete.endsWithWordText(cluster) else { break }
            end = previous
        }
        return (before[..<end], before[end...])
    }

    /// How many characters at the end of `before` make up its last word with the spaces and
    /// punctuation after it, as Option-Delete counts them ("Hello, world. " ends in
    /// "world. "); nil when nothing is before the cursor. Only spaces and punctuation go at once.
    static func wordLength(before: String, stopsAtKhmer: Bool = false) -> Int? {
        guard !before.isEmpty else { return nil }
        var count = 0
        var index = before.endIndex
        while index > before.startIndex, !isWordCharacter(before[before.index(before: index)]) {
            index = before.index(before: index)
            count += 1
        }
        while index > before.startIndex {
            let previous = before.index(before: index)
            guard isWordCharacter(before[previous]),
                  !stopsAtKhmer || !KhmerAutocomplete.endsWithWordText(before[previous..<index]) else { break }
            index = previous
            count += 1
        }
        return count
    }

    /// Letters, digits, emoji and the apostrophe inside "don't" belong to a word.
    private static func isWordCharacter(_ character: Character) -> Bool {
        if character.isLetter || character.isNumber || character == "_" { return true }
        if character == "'" || character == "’" { return true }
        return character.unicodeScalars.first?.properties.isEmojiPresentation == true
    }
}

@MainActor
extension FullKeyboardEngine {
    /// The delete key held down, per `repeatDelay`: one character a tick, two once it
    /// accelerates, whole words after `wordDeleteAfter`.
    func repeatDelete(heldFor: TimeInterval) {
        if heldFor >= Self.wordDeleteAfter {
            deleteWordBackward()
        } else if heldFor >= Self.fastRepeatAfter {
            deleteBackward(takesSwipeBack: false, source: "repeat_fast")
            deleteBackward(takesSwipeBack: false, source: "repeat_fast")
        } else {
            deleteBackward(takesSwipeBack: false, source: "repeat")
        }
    }
}
