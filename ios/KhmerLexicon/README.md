# Khmer typing lexicon

`km-autocomplete.tsv` is the unmodified frequency list from the SIL/Keyman
[`sil.km.ggc` lexical model](https://github.com/keymanapp/lexical-models/tree/e3918e6963c616db501ee7bb6b37d6051f3d59b1/release/sil/sil.km.ggc),
retrieved from commit `e3918e6963c616db501ee7bb6b37d6051f3d59b1`.
The keyboard extension bundles the wordlist and its [upstream MIT notice](km-autocomplete-license.txt).

Wordlist SHA-256 `1127f2c9676e49688fb408b93c87cc9e5a1338ace9ea66b08862ce4b679ed3fc`.

Khmerism Swipe typing uses a memory-mapped unigram model compiled from the same
list. From `ios/`, regenerate it with:

```sh
python3 scripts/build-typing-model.py km KhmerLexicon/km-autocomplete.tsv HEXKeyboard/TypingModel/km.hextm
```

Spelling suggestions use the same frequencies to rank one-edit matches. Valid
dictionary readings and unfinished prefixes take precedence. The keyboard can
automatically repair an unambiguous doubled dependent vowel sign or coeng. It
can restore a missing coeng when one common dictionary word fits. Alternative
repairs at the same word boundary or common repairs at a later boundary keep
the suggestion tap-to-accept.

Six documented spelling rules also apply automatically. Four follow Kong et al.
and two use spellings from Chuon Nath's dictionary. [Research examples, table 5](https://arxiv.org/pdf/2511.09812#page=6)
· [ចំណុច](https://www.thmeythmey.com/index.php/detail/38623)
· [សមត្ថភាព](https://www.thmeythmey.com/detail/80744)

The confirmed misspelling `សាលារ` is corrected to `សាលា` at a known word boundary.
This takes precedence over splitting it into `សាលា` and `រ`.

Custom Vocabulary supplies completions and keeps saved spellings. Learned fixes
can apply at an established word boundary. The shared suggestion filter checks
completions and corrections against a starter list of Khmer spellings
cross-checked with Chuon Nath's and Headley's dictionaries.
[Chuon Nath dictionary data](https://github.com/interscript/khmer-dict-spice/blob/85f37da6d79e9cc8f45a1fe308fc518fa24eddb4/kh_dictionary.csv)

`KhmerAutocompleteTests` checks the documented rules, detection of dictionary
typos, and preservation of valid joined readings and unknown word boundaries.
