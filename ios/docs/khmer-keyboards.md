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
- At the start of a sentence, offer **ខ្ញុំ**, **សូម** and **តើ**. Show up to
  three offline completions from the first letter, including when the letters
  already spell a word. Choosing a completion appends only its missing suffix.
  After a choice, a space, or a zero-width space, rank likely next words from
  the local word-pair model. Typing the start of the next word narrows those
  choices. Tapping **សូម**, **អរគុណ**, then **ច្រើន** writes **សូមអរគុណច្រើន**.
  Predictions and completions work with Autocorrect off.
- The first Khmer code point uses the smaller model's ranking on both layouts.
  Next-word choices and completions from the second code point can use a
  memory-mapped dictionary with 83,312 words and 404,360 word pairs. Khmer
  vowels and marks count as code points even when they share a displayed cluster.
  For example, choose **ខ្ញុំ**, type **បា**, then choose **បានឃើញ** to write
  **ខ្ញុំបានឃើញ** without a space.
  The models use Khmer Wikipedia counts and preferred continuations
  for common conversational phrases. The vocabulary includes Khmer-script Pali
  and Sanskrit. The added spellings complete from a prefix and count as valid
  words. Only terms with measured Khmer dictionary frequencies are eligible
  as dictionary spelling repairs. See the [data credits](acknowledgements.md).
- With Autocorrect on, Space accepts a confident repair and leaves the next word
  joined. A second Space after that repair inserts a literal space. Closing punctuation
  accepts the repair and inserts the typed mark. The double-space punctuation
  shortcut after a word produces **។** followed by a space.
- Offer uncertain spellings for an explicit tap. The quoted spelling keeps
  what was typed. Allow undo in the original field, immediately for a
  Space-accepted correction and after deleting the closing mark for a
  punctuation-accepted one. When a near-edge tap favors a different repair
  from the dictionary, the strip offers the typed spelling and both repairs.
  Tap the spelling you want. Space keeps an uncertain spelling as typed.
- Holding or swiping Backspace left deletes a word at a known boundary,
  including trailing punctuation and whitespace. A held Backspace falls back
  to ordinary host deletion at an uncertain boundary. Sliding back restores
  the deleted word at the same caret. Word swipe deletion and corrections
  that must remove text require an identified field. Moving to another
  field or into emoji search must discard pending edits to the old target.

The keyboard uses the SIL/Keyman Khmer word-frequency list for common completions,
spelling candidates and swipe vocabulary. Rarer entries from ICU, Google, and
Wiktionary extend typing suggestions. [Data sources and notices](acknowledgements.md)

## Personal Khmer suggestions

Turn on **Settings › Experiments › Languages › Personal Khmer suggestions**
on either layout. It is off by default and requires **Learn how I type**.
After two uses, a word can rank higher in prefix completions, and a word
pair can rank higher after its first word. Suggestions still require a tap.

Hex counts words you pick from the strip and words you type and finish with
a space, punctuation, or Return. To teach a new spelling, type it twice as a
separate word. A short unfamiliar spelling can become a personal completion
and take part in next-word predictions. Joined text teaches word pairs when
Hex can find an unambiguous reading. Use spaces when entering new words amid
joined text so Hex can tell where the new word starts and ends. Pasted text
alone and secure fields teach nothing.
Only bounded word and pair counts are stored on the iPhone. Turning the
experiment off pauses learning and restores the usual suggestions.
When counts exist, **Settings › Privacy › Export Khmer learning data** saves
`hex-khmer-learning.json` to a location you choose. `words` maps each retained
word to its count. `pairs` maps each preceding word to its following words
and their counts. The file includes counts of one and contains only Khmer
suggestion data. You can export saved counts while learning is paused.
**Settings › Privacy › Learn how I type › Delete what Hex learned** clears
the on-device counts. Saved exports are separate files.

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
  layout. Personal words can be swiped too, including a single syllable
  traced across two keys. Main and shifted characters can share a physical
  position. Lifting normally inserts the best reading. When two readings
  are close, an identified field with a visible suggestion strip can wait
  for a choice. Backspace dismisses the choice and preserves the field text.
  Swiping also works in emoji search and ordinary text fields that turn off
  spelling correction. Address and credential fields keep literal key input.
  Consecutive swipes join without spaces. Normal taps and holds remain
  available, including while VoiceOver is active or the caret follows coeng.
  In an identified field, Backspace can take back the last swipe as one word
  according to Hex's existing letter-by-letter deletion setting.

## English suggestions

Turn on **Settings › Experiments › Languages › English suggestions in Khmer**
to see English spellings for matched loanwords and app names on either layout.
Type **តេឡេក្** to see both **តេឡេក្រាម** and **Telegram**. A partial spelling
can qualify as soon as it identifies one English result. For example, **ម៉ៃក្រូ**
still fits both Microsoft and microphone, so the keyboard waits for more input.
When an ordinary Khmer completion also fits, it can appear alongside the two
spellings. Search fields can offer both spellings with autocorrection off.

Matching works offline, including in joined Khmer text. For example, tapping
**computer** after **ម៉ៅស៍កុំព្យូទ័រ** keeps **ម៉ៅស៍** and replaces **កុំព្យូទ័រ**.
Following punctuation stays in place. Space keeps what you typed.

The [Khmer-to-English transliteration lexicon](../HEXKeyboard/TypingModel/km-english-suggestions.tsv)
contains app names, Cambodian services, and everyday digital loanwords. Each
row pairs one Khmer spelling with the English text Hex inserts. Spellings
that should insert the same text share that English spelling.

Hex maintains this list, including informal Khmer spellings. References for
loanwords and terminology include [Wiktionary’s Khmer loanword category](https://en.wiktionary.org/wiki/Category:Khmer_terms_borrowed_from_English)
and the [Cambodian Ministry of Posts and Telecommunications digital glossary](https://mptc.gov.kh/lexicon/).

## Acceptance examples

| Try this in the Full keyboard | Expected result |
| --- | --- |
| In an empty field, tap **ខ្ញុំ**, then **ចង់**. Type **។**. | The field reads **ខ្ញុំចង់។** and the three sentence starters reappear. |
| Start typing **គច្ឆាមិ** or **មហាយាន** on either layout. | The strip can complete the spelling. Selecting it inserts the remaining letters. |
| Type **ក**, then try **សា** in a fresh field. | **ក** offers **ការ**, **ក្នុង** and **កម្ពុជា**. **សា** offers **សាលា** and stays as typed until a choice is tapped. |
| Enter **ស + ◌្** on each layout. On Khmer, tap **ថ**. On Khmerism, tap the position that usually types **◌ោ**. | Both give **ស្ថ**. The Khmerism key then shows **◌ោ** again. |
| Tap **ញ + ◌ំ** in an ordinary text field with the default settings. Repeat with Autocorrect off. | **ខ្ញុំ** first, then literal **ញំ**. |
| With Autocorrect off, type **កម្** and choose **កម្ពុជា**. | The keyboard appends **ពុជា** once, preserving the coeng in the prefix. |
| With Autocorrect on, type **សាលារ**. Continue with **ៀន**, or press Space at the prefix. | Continuing gives **សាលារៀន**. Space keeps the final **រ** and inserts a space. |
| With Autocorrect on and no learned corrections, type **ចំនុច**. | Tap **ចំណុច** to accept the spelling suggestion. Pressing Space instead keeps **ចំនុច** and inserts a space. |
| Swipe Backspace left one word at the end of **ខ្ញុំទៅសាលា។** followed by a space. Slide back before lifting. | The field first reads **ខ្ញុំទៅ**, then recovers the exact original text, including punctuation and space. |
| With swipe enabled, trace **បាន** then **ខ្ញុំ**. With whole-word swipe deletion enabled, press Backspace. | **បានខ្ញុំ** becomes **បាន**. A preceding word survives. |

The reference tests exercise key maps, editor behavior with simulated host
fields, and synthetic swipe paths. Recognition accuracy with Khmer typists on
physical devices remains unmeasured.

For the November 2026 word-pair model, an offline evaluation used the
[November 21 Khmer Tatoeba export](https://downloads.tatoeba.org/exports/per_language/khm/).
After excluding sentences found verbatim after normalization in the Wikipedia
training text, the evaluation ranked the next word given the preceding ICU-segmented
word. The previous keyboard placed it in the first three choices on 496 of 8,529
opportunities (5.82%). The new model did so on 1,095 (12.84%). These are
sentence-level data from a small set of contributors. The comparison supplies
word boundaries and does not measure taps saved in real conversations.
