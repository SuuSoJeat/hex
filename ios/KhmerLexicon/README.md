# Khmer typing lexicon

`km-autocomplete.tsv` is the unmodified frequency list from the SIL/Keyman
[`sil.km.ggc` lexical model](https://github.com/keymanapp/lexical-models/tree/e3918e6963c616db501ee7bb6b37d6051f3d59b1/release/sil/sil.km.ggc),
retrieved from commit `e3918e6963c616db501ee7bb6b37d6051f3d59b1`.
The keyboard extension bundles the wordlist and its [upstream MIT notice](km-autocomplete-license.txt).

Wordlist SHA-256 `1127f2c9676e49688fb408b93c87cc9e5a1338ace9ea66b08862ce4b679ed3fc`.

The autocorrection list covers six exact misspellings. Four follow Kong et al.
and two use spellings from Chuon Nath's dictionary. [Research examples, table 5](https://arxiv.org/pdf/2511.09812#page=6)
· [ចំណុច](https://www.thmeythmey.com/index.php/detail/38623)
· [សមត្ថភាព](https://www.thmeythmey.com/detail/80744)

`KhmerAutocompleteTests` checks all six against the bundled wordlist and checks
preservation of valid joined readings and unknown word boundaries.
