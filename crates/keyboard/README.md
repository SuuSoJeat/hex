# Hex keyboard core

The keyboard's platform-independent logic in Rust, shared by the iOS keyboard extension
(`ios/HEXKeyboard`, through `ios/HEXShared`) and the Android IME (`android/app`). Each OS
keeps its own layer on top: views, touches, the text field, haptics, dictation, storage, and
anything only the OS can answer (Apple's spelling checker, the system lexicon).

- `core/` (`hex-keyboard-core`): safe Rust. It never reads a clock, a file or the OS; the
  host passes in times, key geometry and data.
- `ffi/` (`hex-keyboard-ffi`, library `hex_keyboard`): the C interface in
  `include/hex_keyboard.h` (Swift imports it as `HexKeyboardCore`), and with the `jni`
  feature the Android entry points. All `unsafe` code is here; every entry point catches
  panics.

This is its own Cargo workspace with its own `Cargo.lock` and pinned toolchain
(`rust-toolchain.toml`), so the desktop workspace never builds it.

Pieces move here one at a time from the Swift keyboard (`ios/HEXShared/FullKeyboard`), each
proven identical to the Swift it replaces before iOS switches to it. Today: the typing
model reader, Swipe typing's decoder, the tap decoder (Spatial autocorrect,
`core/src/decoder`) and autocorrect's decisions (`core/src/autocorrect`). Tune those here, not
in Swift.

```sh
cd crates/keyboard
cargo test
cargo clippy --all-targets -- -D warnings
```

## The tap decoder

`core/src/decoder` is `TypingDecoder` (`ios/HEXShared/FullKeyboard/TypingDecoder.swift`)
step for step, with one difference: where Swift walks a dictionary, readings that cost
exactly the same came out in an order that changed from run to run; here a tie in the search
goes to the commoner word, then the one earlier in the word list, and a tie between
run-together readings to the one with fewer words. About 1% of the parity cases have such a
tie (`tests/tap_parity.rs`).

`tests/tap_parity.rs` replays `tests/fixtures/tap-parity.jsonl`, cases the Swift oracle
(`ios/HEXMobileTests/TapParity`) wrote, and must match them bit for bit; it says how to
write the fixture again, or a larger set for `HEX_TAP_PARITY=/path`.

`examples/tap_replay.rs` replays a typing set through the decoder alone and prints its word
error rate and per-word latency as the Android benchmark (`android/benchmark/typing`) does.
It reads that benchmark's synthetic JSON Lines (`export_synthetic.py`; the sets aren't in the
repository) or iOS's tap JSON (`ios/README.md`, "Replaying real typing"). It leaves out
everything around the decoder (the engine's contraction and typo rules, the dictionary,
capitals, the strip), so compare its numbers only with its own.

```sh
cargo run --release -p hex-keyboard-core --example tap_replay -- \
  /path/en-test.jsonl ../../ios/HEXKeyboard/TypingModel/en.hextm
# a small set of its own, for a smoke test
cargo run --release -p hex-keyboard-core --example tap_replay -- \
  --make-sample 200 /tmp/sample.jsonl ../../ios/HEXKeyboard/TypingModel/en.hextm
```

## Autocorrect

`core/src/autocorrect` is `AutocorrectEngine` (`ios/HEXShared/FullKeyboard/AutocorrectEngine*.swift`)
decision for decision: the strip, what space puts in, the next word's revision of the word
before, bilingual autocorrect's partner language, and the helpers they read (the never-suggest
list, German's capitals, Learn how I type's typos). The spelling dictionary stays the host's,
behind `TextChecker` (iOS: `UITextChecker`), asked in the same order the Swift asked; your
lexicon, vocabulary, kept words (the host keeps `LearnedWordsStore` on disk), settings and the
field come in as data. `autocorrect::text` replicates the Swift and Foundation string semantics
the decisions read by (grapheme clusters, canonical equivalence, `caseInsensitiveCompare`,
diacritic folding).

`tests/autocorrect_parity` replays `tests/fixtures/autocorrect-parity.jsonl`, cases the Swift
oracle (`ios/HEXMobileTests/AutocorrectParity`) wrote with a deterministic dictionary, and must
give the same answers, the same engine state and the same dictionary calls in the same order;
it says how to write the fixture again, or a larger set for `HEX_AUTOCORRECT_PARITY=/path`.
