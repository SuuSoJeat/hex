# Acknowledgements

Part of [Hex for iPhone](../README.md).

The app shows these under Settings › Acknowledgements (`HEXMobile/AcknowledgementsView.swift`).

- **Google Books Ngram data:** Spatial autocorrect's word and word-pair frequencies,
  German's capitalisation shares and French's list of words outside its model come from the Google Books Ngram Viewer data, version 3
  (2020), by Google, licensed under
  [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/). Counts
  are summed over 1980–2019 and kept only for words in the lists below.
- **SCOWL:** English words are checked against SCOWL (Spell Checker Oriented Word Lists)
  and VarCon by Kevin Atkinson, sizes up to 70 (<http://wordlist.aspell.net/>). Copyright
  2000-2018 by Kevin Atkinson. Permission to use, copy, modify, distribute and sell these
  word lists, the associated scripts, the output created from the scripts, and its
  documentation for any purpose is hereby granted without fee, provided that the above
  copyright notice appears in all copies and that both that copyright notice and this
  permission notice appear in supporting documentation. Kevin Atkinson makes no
  representations about the suitability of this array for any purpose. It is provided
  "as is" without express or implied warranty. SCOWL's inflections come from WordNet 1.6,
  Copyright 1997 by Princeton University, all rights reserved, provided "as is" without
  warranties (the full notice is in the app); its other sources are public domain.
- **Leipzig Corpora Collection:** English words newer than the books and their spellings
  ("ChatGPT", "TikTok") come from the [Leipzig Corpora Collection](https://wortschatz-leipzig.de/en/download)'s
  English news downloads for 2023, 2024 and 2025, Leipzig University and the Saxon Academy
  of Sciences and Humanities in Leipzig (D. Goldhahn, T. Eckart and U. Quasthoff, LREC 2012),
  licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
  Hex keeps only word counts, how many sites use each word and its spellings.
- **LDNOOBW:** The keyboard's suggestion filter uses the
  [List of Dirty, Naughty, Obscene, and Otherwise Bad Words](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/tree/5faf2ba42d7b1c0977169ec3611df25a3c08eb13)
  (LDNOOBW), © 2012–2020 Shutterstock, Inc., and contributors: its English, Spanish,
  German and Norwegian lists, licensed under
  [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
  Hex lowercased and classified the entries, omitted ordinary, medical and search-only
  terms, and added common slurs, inflections and spelling variants.
- **Parakeet V2:** Hex dictates English with NVIDIA's
  [Parakeet TDT 0.6B v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2), licensed under
  [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/),
  downloaded as FluidInference's
  [Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml)
  (CC BY 4.0, encoder weights at reduced precision), used unchanged.
- **Parakeet Ultra:** Settings › Dictation › Model: Multilingual downloads
  [Parakeet Ultra](https://huggingface.co/moondream/parakeet-ultra) by Moondream, a
  post-training of NVIDIA's
  [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), both licensed
  under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/),
  as FluidInference's [Core ML conversion](https://huggingface.co/FluidInference/parakeet-ultra-coreml)
  (revision `95eaa59`: 8-bit integer encoder weights, decoder and joint re-exported), used
  unchanged.
- **RLA-ES:** Spanish words are checked against RLA-ES, the Spanish spelling dictionaries
  for LibreOffice by Santiago Bosio and contributors (Spain and Mexico), used under the
  [Mozilla Public License 1.1](https://www.mozilla.org/en-US/MPL/1.1/)
  (<https://github.com/sbosio/rla-es>).
- **SIL/Keyman Khmer lexical model.** Khmer completions and spelling suggestions use the
  unchanged word frequency list from SIL International's
  [`sil.km.ggc` model](https://github.com/keymanapp/lexical-models/tree/e3918e6963c616db501ee7bb6b37d6051f3d59b1/release/sil/sil.km.ggc).
  The bundled TSV has SHA-256 `1127f2c9676e49688fb408b93c87cc9e5a1338ace9ea66b08862ce4b679ed3fc`.
  From `ios/`, regenerate the swipe model with
  `python3 scripts/build-typing-model.py km HEXKeyboard/TypingModel/km-autocomplete.tsv HEXKeyboard/TypingModel/km.hextm`.
  Copyright © 2024 SIL International.
  The keyboard includes the [MIT licence notice](../HEXKeyboard/TypingModel/km-autocomplete-license.txt).
- **Khmer Wikipedia contributors.** Khmer next-word predictions use adjacent words
  from the [November 2023 Khmer Wikipedia snapshot](https://huggingface.co/datasets/wikimedia/wikipedia/tree/b04c8d1ceb2f5cd4588862100d08de323dccfbaa/20231101.km).
  The snapshot credits Wikipedia contributors and lists CC BY-SA 3.0. Hex distributes the
  adapted pair data under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
  Each article URL in the snapshot links to the contributors through its history.
  To reproduce the counts, download the linked Parquet file and run
  `python3 ios/scripts/count-khmer-word-pairs.py path/to/snapshot.parquet` with
  ICU 78.3, PyICU 2.16.2 and PyArrow 23.0.1. The script checks the snapshot hash,
  segments the text, and counts known words seen together on two or more pages.
  The model builder combines those counts with Hex's ranked conversational phrases.
- **Pali, Sanskrit and Buddhist vocabulary.** The [supplemental wordlist](../HEXKeyboard/TypingModel/km-buddhist.txt)
  credits English Wiktionary contributors for Khmer-script entries and Khmer loanwords,
  and lists the spelling references for additional chanting and Buddhist terms. The
  Wiktionary-derived lists are distributed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
  The keyboard gives these uncounted spellings lower completion priority than the SIL terms.
- **Expanded Khmer dictionary.** Hex adds 60,883 spellings from the
  [ICU Khmer break dictionary](https://github.com/unicode-org/icu/blob/release-78.3/icu4c/source/data/brkitr/dictionaries/khmerdict.txt),
  1,269 spellings from [Google's Khmer pronunciation dictionary](https://github.com/google/language-resources/blob/a906010/km/data/lexicon.tsv),
  and 332 English Wiktionary headwords from the [Kaikki Khmer extraction](https://kaikki.org/dictionary/Khmer/index.html).
  The [bundled notice](../HEXKeyboard/TypingModel/km-expanded-license.txt) credits the
  contributors and describes how Hex adapted each source. The expanded model uses the
  same pinned Khmer Wikipedia snapshot as the smaller model. From the repository root,
  rebuild it with `python3 ios/scripts/count-khmer-word-pairs.py path/to/snapshot.parquet --expanded-dictionary path/to/khmerdict.txt --output ios/HEXKeyboard/TypingModel/km-expanded.hextm`.
- **Khmerism keyboard layout.** Hex's Khmerism layout builds on the original
  [Khmerism Keyboard Project by Lyheng Phuoy](https://solve.mit.edu/solutions/2452).
  See the [key maps](khmer-keyboards.md#key-maps) for the Hex adaptation.

Polish's three entries show while the keyboard bundles `pl.hextm`
(`AcknowledgementsView.polishEntries`):

- **National Corpus of Polish n-grams:** Polish word and word-pair frequencies come from
  the n-grams of NKJP's balanced subcorpus (Institute of Computer Science, Polish Academy
  of Sciences; <http://zil.ipipan.waw.pl/NKJPNGrams>), made available under a
  [Creative Commons Attribution](https://creativecommons.org/licenses/by/) licence (the page
  names no version).
- **ParlaMint:** which Polish spellings are missing their marks, and which words are names, is
  checked against the Polish part of ParlaMint 5.0 (Erjavec et al., CLARIN.SI, <http://hdl.handle.net/11356/2004>),
  licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **PoliMorf:** Polish words are checked against PoliMorf 2018-07-23
  (<http://hdl.handle.net/11321/577>), under the 2-clause BSD licence whose notice the app
  reproduces in full: portions copyright © 2011 Marek Futrega, Piotr Gackiewicz, Mirosław
  Prywata, Włodzimierz Macewicz, Marcin Miłkowski; © 2007–2018 Zygmunt Saloni, Włodzimierz
  Gruszczyński, Marcin Woliński, Robert Wołosz, Danuta Skowrońska; © 2011–2018 Institute of
  Computer Science, Polish Academy of Sciences.
