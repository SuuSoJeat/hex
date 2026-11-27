import UIKit

/// The one edit notification: kept beside the engine like the trackpad's own code so
/// `FullKeyboardEngine.swift` stays readable.
@MainActor
extension FullKeyboardEngine {
    /// What the field asks for, or no automatic capitals with Auto-capitalization off.
    var autoCapitalizationMode: AutoCapitalization.Mode {
        guard language.supportsAutoCapitalization, layout.language != .khmer, autoCapitalizes else { return .none }
        return AutoCapitalization.Mode(target.autocapitalizationType)
    }

    func refreshAutoCapitalization() {
        // Khmer uses Shift for alternate characters, without automatic capitalization.
        guard layout.language != .khmer else { return }
        let before = shift
        shift.refreshAutoCapitalization(
            AutoCapitalization.shouldCapitalize(
                mode: autoCapitalizationMode,
                before: typingContext,
                hasText: target.hasText,
                language: layout.language
            )
        )
        if shift != before {
            logState("auto")
            onChange?()
        }
    }

    enum EditKind {
        case normal
        case resolvingObscuredSwipe
    }

    func didEdit(_ kind: EditKind = .normal) {
        dismissKhmerSwipeChoices()
        suggestionSpaceBefore = nil
        swipeRetries.edited()
        // A key's own edit means a pending Dictate no longer has the field it picked.
        trackpadSelectionState.pendingDictation = nil
        refreshAutoCapitalization()
        refreshSuggestions()
        onEdit?(kind)
    }
}
