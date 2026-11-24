/// One slot in the 3-column suggestion strip above the keys.
nonisolated struct KeyboardSuggestion: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Left slot (`"typed"`): keeps the exact characters and teaches Hex not to rewrite them.
        case keepLiteral
        /// Center slot: best replacement or completion (`autoReplace` highlights when Space will apply it).
        case primary(autoReplace: Bool)
        /// Right slot: runner-up completion or spelling guess.
        case secondary
        /// A Khmer word whose remaining characters can be appended at the caret.
        case khmerCompletion
        /// A Khmer sentence starter or following word, inserted without a separator.
        case khmerPrediction
        /// The Khmer spelling as typed, and a replacement that may apply on a word boundary.
        case khmerKeepLiteral
        case khmerCorrection(autoReplace: Bool)
        /// An English spelling that replaces the matched Khmer word on tap.
        case khmerEnglish(typed: String)
        /// A word that can follow the one just finished. Only an explicit pick inserts it.
        case nextWord
        /// An emoji for the word just finished (Settings › Keyboard › Emoji), offered after a space,
        /// when the strip has no words to show.
        case emoji
        /// Another reading of the word just swiped (Settings › Keyboard › Swipe typing): tapping it
        /// puts it in that word's place.
        case swiped
        /// What you typed before autocorrect changed it, offered once the cursor is back at the
        /// end of the corrected words (delete takes only their space): tapping it puts it back.
        case revert
    }

    let displayText: String
    let replacement: String
    let kind: Kind

    var willAutoReplace: Bool {
        switch kind {
        case .primary(let auto), .khmerCorrection(let auto): auto
        default: false
        }
    }
}
