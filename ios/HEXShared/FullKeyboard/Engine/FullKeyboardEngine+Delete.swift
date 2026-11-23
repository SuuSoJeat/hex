import UIKit

@MainActor
extension FullKeyboardEngine {
    /// The delete key repeats after 360 ms, accelerates at 850 ms, and removes whole words after 1.4 s.
    static let repeatDelay: TimeInterval = 0.36
    static let repeatInterval: TimeInterval = 0.075
    static let fastRepeatAfter: TimeInterval = 0.85
    static let wordDeleteAfter: TimeInterval = 1.4

    /// Delete right after an autocorrection takes only the space or mark after it, as Apple's
    /// keyboard does (black box, iOS 27.2), and the strip then offers what you typed
    /// (`offeringRevert`); Adaptive touch keeps the word's taps for that revert.
    func deleteBackward(takesSwipeBack: Bool = true, source: String = "key") {
        guard khmerDeleteRecovery == nil else { return }
        if deleteHangulBackward() { return }
        // The held space is a boundary question that deletes nothing: ask it before forgetting
        // what Hex typed, and keep the record when it answers, as the text has not changed.
        if takesSwipeBack, dropsHeldSpace() { return }
        forgetTypingContext()
        // Right after a swipe, delete takes back its whole word (and the space it added),
        // unless its experiment asks for one character at a time, as anywhere else.
        let swiped = swipedWord
        swipedWord = nil
        swipeRetries.willDelete(letterOf: takesSwipeBack && deletesSwipedWordsLetterByLetter ? swiped : nil)
        if takesSwipeBack, !deletesSwipedWordsLetterByLetter, let swiped, deleteSwipedWord(swiped) { return }
        let before = textBefore
        learning?.willErase(word: AutocorrectEngine.currentToken(in: before))
        if autocorrect.revertibleCorrection(before: before.map { String($0.dropLast()) }, document: target.documentIdentifier) == nil {
            adaptiveLearning?.willDelete(before: before)
        }
        if let log = typingLog {
            let deleted = target.documentContextBeforeInput?.last.map { String($0) }
            log.edit("delete", [
                deleted.map { TypingLogField("deleted", .string($0)) } ?? TypingLogField("deletedCount", .int(1)),
                TypingLogField("src", .string(source)),
            ])
        }
        if let last = textBefore?.last, last.isLetter || last == "'", !tokenTaps.isEmpty {
            tokenTaps.removeLast()
        } else {
            tokenTaps.removeAll()
        }
        target.deleteBackward()
        lastSpaceAt = nil
        didEdit()
    }

    func deleteWordBackward() {
        guard khmerDeleteRecovery == nil else { return }
        commitHangulComposition()
        forgetTypingContext()
        swipedWord = nil
        adaptiveTouch?.forget()
        guard let before = textBefore, !before.isEmpty else {
            deleteBackward(takesSwipeBack: false, source: "repeat_word")
            return
        }
        if layout.language == .khmer {
            guard let suffix = khmerWordToDelete(before: before) else {
                deleteBackward(takesSwipeBack: false, source: "repeat_word")
                return
            }
            switch deleteKhmerWord(suffix, before: before, source: "repeat_word") {
            case .rejected:
                deleteBackward(takesSwipeBack: false, source: "repeat_word")
            case .interrupted:
                break
            case .removed:
                didEdit()
                typingLog?.context("delete_word")
            }
            return
        }
        learning?.willErase(word: AutocorrectEngine.currentToken(in: before))
        var count = 0
        var index = before.endIndex
        while index > before.startIndex, before[before.index(before: index)].isWhitespace {
            index = before.index(before: index)
            count += 1
        }
        while index > before.startIndex, !before[before.index(before: index)].isWhitespace {
            index = before.index(before: index)
            count += 1
        }
        tokenTaps.removeAll()
        typingLog?.edit("delete_word", [
            TypingLogField("deleted", .string(String(before.suffix(max(1, count))))),
            TypingLogField("src", .string("repeat_word")),
        ])
        for _ in 0..<max(1, count) {
            target.deleteBackward()
        }
        lastSpaceAt = nil
        didEdit()
        typingLog?.context("delete_word")
    }
}
