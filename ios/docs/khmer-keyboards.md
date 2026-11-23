# Khmer keyboards for Hex on iOS

Add **ភាសាខ្មែរ** (Khmer, `km-KH`) to the Full keyboard's existing language
picker. Someone who already types Khmer on an iPhone should be able to start
with familiar keys. Someone who uses Khmerism should be able to choose that
arrangement under **Layout**, with the same editor, suggestion strip and
language-switching gesture. The default for Khmer is the iPhone-style layout.
This request concerns typing in the iOS keyboard extension.

## Key maps

Read each line from left to right. The first entry on each layer belongs to the
first key, the second entry to the second key, and so on. A dotted circle (◌) makes a combining mark visible here.
The key inserts only the mark. For example, **ស + ◌្ + ថ** inserts **ស្ថ**
(`U+179F U+17D2 U+1790`). Coeng (`U+17D2`) followed by a consonant encodes its
subscript form. [Unicode Standard, section 16.4](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-16/#G37574)

### Khmer (iPhone-style)

The reference for these positions is the Khmer keyboard observed on iOS 27.2.
Shift chooses the second output. The letter positions stay fixed after coeng.
Shift and Delete flank the fourth letter row.

```text
Row 1  Base   ១ ២ ៣ ៤ ៥ ៦ ៧ ៨ ៩ ០ ឥ ឲ
       Shift  ! ៗ " ៛ % ◌៍ ◌័ ◌៏ ឰ ឳ ◌៌ ◌៎
Row 2  Base   ឆ ◌ឹ ◌េ រ ត យ ◌ុ ◌ិ ◌ោ ផ ◌ៀ ឪ
       Shift  ឈ ◌ឺ ◌ែ ឬ ទ ◌ួ ◌ូ ◌ី ◌ៅ ភ ◌ឿ ឧ
Row 3  Base   ◌ា ស ដ ថ ង ហ ◌្ ក ល ◌ើ ◌់ ឭ
       Shift  ឫ ◌ៃ ឌ ធ អ ◌ះ ញ គ ឡ ៖ ◌៉ ឮ
Row 4  Base   ឋ ខ ច វ ប ន ម ឦ ។ ◌៊
       Shift  ឍ ឃ ជ ◌ៈ ព ណ ◌ំ ឱ ៕ ឯ
```

The **123** and **#+=** pages have three character rows above the footer.
The **ក** key returns to letters.

```text
123    1 2 3 4 5 6 7 8 9 0
       « » @ ◌៑ ៛ / ៙ ៚ ( )
       ឩ ឝ ឞ ? !

#+=    [ ] { } # % ^ * + =
       - _ : ; < > $ £ € •
       . , ' ? !
```

### Khmerism

This layout adapts Lyheng Phuoy's Khmerism design for Hex. Tap for the main
character or hold for the corner character. Shift exchanges the two outputs for
one keystroke. Double-tap Shift to lock and tap again to unlock. Shift and
Delete flank row four. The last two keys sit immediately to the right of Space.
[Khmerism Keyboard Project](https://solve.mit.edu/solutions/2452)

```text
Row 1  Main    ហ ណ ញ យ វ ◌៉ ◌ៅ ◌ៃ ◌ើ ◌ឿ ◌ៀ
       Corner  ១ ២ ៣ ៤ ៥ ◌៊ ◌ៈ ◌៏ ◌៍ ◌័ ◌៌
Row 2  Main    ដ ត ប ក ច ◌ោ ◌ែ ◌ិ ◌ី ◌ឹ ◌ឺ
       Corner  ៦ ៧ ៨ ៩ ០ ថ ធ ខ ឃ ◌៎ .
Row 3  Main    ស ន ម ង ល ◌េ រ ◌្ ◌ា ◌ះ ៗ
       Corner  ឬ ឮ ឯ ឥ ឧ ឡ ឲ ផ ភ ឆ ឈ
Row 4  Main    ឌ ទ ព គ ជ អ ◌ុ ◌ូ ◌ួ
       Corner  ឫ ឭ ឰ ឦ ឪ ឱ ឋ ឍ ៛
Footer Main    ◌ំ ◌់
       Corner  ។ ?
```

Immediately after coeng, eleven keys offer a subscript consonant on tap.
The two lines below correspond position for position. Hold a changed key for
its usual output. All corners are hidden in this state. Manual Shift takes
precedence. Moving the caret away from coeng restores the ordinary map.

```text
Usual key    ◌ោ ◌ែ ◌ិ ◌ី ◌េ ◌្ ◌ា ◌ះ ៗ ◌ុ ◌ូ
After coeng  ថ  ធ  ខ  ឃ  ឡ  ផ  ភ  ឆ  ឈ ឋ  ឍ
```

**123** and **#+=** reuse Hex's English character rows. The number page adds
**។** and **៕** beside Space. The symbol page adds **។** and **៖**, whose holds
produce **៙** and **៚** respectively. Space, Return and **កខគ** return to letters.
Khmerism stays joined on an unfolded keyboard and puts Hex and Globe in the
strip to make room for its footer. Marks are teal, independent vowels green
and Khmer digits rose. The **No colors** and **No superscripts** appearance
options each default off. Hiding corner labels preserves hold-to-type.

## Shared editing behavior

- Use the existing controls for language switching on Space, emoji, Number Row,
  pop-ups and field-specific punctuation. The iPhone-style layout also follows
  the user's Hex/Globe placement, optional comma and period keys, and unfolded
  split preference.
- Insert Khmer in typing order. With Autocorrect off, two presses on a vowel
  insert the vowel twice. Shape an entire suggestion together so that a
  highlighted prefix can end in coeng without separating the subscript.
- Offer up to three offline completions, including with Autocorrect off.
  Choosing one appends the missing suffix with no separator. With Autocorrect
  on, Space accepts a confident repair and leaves the next word joined. A
  second Space after that repair inserts a literal space. Closing punctuation
  accepts the repair and inserts the typed mark. The double-space punctuation
  shortcut after a word produces **។** followed by a space.
- Offer uncertain spellings for an explicit tap. The quoted spelling keeps
  what was typed. Allow undo in the original field, immediately for a
  Space-accepted correction and after deleting the closing mark for a
  punctuation-accepted one. Spatial autocorrect can use near-edge taps to rank
  candidates. Those rankings apply to the user's choice in the strip.
- Holding or swiping Backspace left deletes a word at a known boundary,
  including trailing punctuation and whitespace. A held Backspace falls back
  to ordinary host deletion at an uncertain boundary. Sliding back restores
  the deleted word at the same caret. Word swipe deletion and corrections
  that must remove text require an identified field. Moving to another
  field or into emoji search must discard pending edits to the old target.

The prototype uses the SIL/Keyman Khmer word-frequency list for completions,
spelling candidates and swipe vocabulary. It retains the MIT notice for the
list. [SIL lexical model](https://github.com/keymanapp/lexical-models/tree/e3918e6963c616db501ee7bb6b37d6051f3d59b1/release/sil/sil.km.ggc)

## Smart typing and swipe typing

Both layouts use the existing **Autocorrect** and **Swipe typing** switches in
**Settings › Keyboard**. Both default on and can be turned off independently.

- With **Autocorrect** on, smart typing acts on the syllable just entered in an eligible text field.
  Tapping **ញ + ◌ំ** produces **ខ្ញុំ**. Subscript ញ and text already in the
  field retain their spelling. The sign key (◌៉ on Khmerism, ◌៊ on Khmer) offers
  the sign for **ក៏ ដ៏ ន៍ ស៊ ហ៊ អ៊ ប៉** after its respective consonant. Two
  taps within 350 ms on **◌ា**, **◌េ** or **◌ោ** produce **◌ាំ**, **◌េះ** or
  **◌ោះ** respectively. An explicit register shifter goes after the base,
  replacing any prior shifter. A first vowel goes before trailing final signs.
  Address, credential and correction-disabled fields retain literal input.
- With **Swipe typing** on, trace one
  word in encoded order, including coeng and vowel signs, on the selected
  layout. Main and shifted characters can share a physical position. When
  two readings are close, an identified field with a visible suggestion strip
  can wait for a choice. Otherwise, lifting inserts the best reading.
  Consecutive swipes join without spaces. Normal taps and holds remain
  available, including while VoiceOver is active or the caret follows coeng.
  In an identified field, Backspace can take back the last swipe as one word
  according to Hex's existing letter-by-letter deletion setting.

## Acceptance examples

| Try this in the Full keyboard | Expected result |
| --- | --- |
| Enter **ស + ◌្** on each layout. On Khmer, tap **ថ**. On Khmerism, tap the position that usually types **◌ោ**. | Both give **ស្ថ**. The Khmerism key then shows **◌ោ** again. |
| Tap **ញ + ◌ំ** in an ordinary text field with the default settings. Repeat with Autocorrect off. | **ខ្ញុំ** first, then literal **ញំ**. |
| With Autocorrect off, type **កម្** and choose **កម្ពុជា**. | The keyboard appends **ពុជា** once, preserving the coeng in the prefix. |
| With Autocorrect on, type **សាលារ**. Continue with **ៀន**, or press Space at the prefix. | Continuing gives **សាលារៀន**. Space keeps the final **រ** and inserts a space. |
| Swipe Backspace left one word at the end of **ខ្ញុំទៅសាលា។** followed by a space. Slide back before lifting. | The field first reads **ខ្ញុំទៅ**, then recovers the exact original text, including punctuation and space. |
| With swipe enabled, trace **បាន** then **ខ្ញុំ**. With whole-word swipe deletion enabled, press Backspace. | **បានខ្ញុំ** becomes **បាន**. A preceding word survives. |

The reference tests exercise key maps, editor behavior with simulated host
fields, and synthetic swipe paths. Recognition accuracy with Khmer typists on
physical devices remains unmeasured.
