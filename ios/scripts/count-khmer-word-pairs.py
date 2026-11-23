#!/usr/bin/env python3
"""Count known adjacent words in the 2023-11-01 Khmer Wikipedia snapshot.

Download 20231101.km/train-00000-of-00001.parquet from wikimedia/wikipedia at
b04c8d1ceb2f5cd4588862100d08de323dccfbaa. Requires pyarrow and PyICU with
ICU 78.3 (its Khmer dictionary determines the boundaries). Run from any cwd:
    python3 ios/scripts/count-khmer-word-pairs.py path/to/snapshot.parquet
For the expanded model, also download khmerdict.txt from
https://github.com/unicode-org/icu/tree/release-78.3/icu4c/source/data/brkitr/dictionaries.
    python3 ios/scripts/count-khmer-word-pairs.py path/to/snapshot.parquet \
        --expanded-dictionary path/to/khmerdict.txt --output path/to/km-expanded.hextm
Both models build offline from local inputs. The keyboard ships the compiled models.
"""

import argparse
import gzip
import hashlib
from collections import Counter
from importlib import import_module
from pathlib import Path

import icu
import pyarrow.parquet as parquet

SCRIPTS = Path(__file__).resolve().parent
VOCABULARY = SCRIPTS.parent / "HEXKeyboard/TypingModel/km-autocomplete.tsv"
ICU_DICTIONARY_SHA256 = "87bee2d17cd5148aa36957eb05409eefc124de8ad519b81b789298ef3e60b5d9"
SNAPSHOT_SHA256 = "329b1bdc81a392e4c401a1ff70f9894454db136b58cf71fe90cf31d80afdda64"


def article_pairs(text, words, breaker):
    counts = Counter()
    # ICU returns UTF-16 offsets. UnicodeString indexes the same way even when
    # the article contains supplementary characters outside Khmer.
    article = icu.UnicodeString(text)
    breaker.setText(article)
    start = breaker.first()
    previous = None
    for end in breaker:
        token = str(article[start:end])
        start = end
        if token in words:
            if previous and token != previous:
                counts[previous, token] += 1
            previous = token
        elif not all(char in " \t\u00a0\u200b" for char in token):
            previous = None
    return counts


def corpus_counts(snapshot, words):
    breaker = icu.BreakIterator.createWordInstance(icu.Locale("km"))
    frequencies = Counter()
    documents = Counter()
    articles = parquet.ParquetFile(snapshot)
    for batch in articles.iter_batches(batch_size=64, columns=["text"]):
        for article in batch.column(0).to_pylist():
            counts = article_pairs(article, words, breaker)
            documents.update(counts.keys())
            # Repeated names and templates on a single page should carry little weight.
            frequencies.update({pair: min(count, 3) for pair, count in counts.items()})
    print(f"{articles.metadata.num_rows:,} articles")
    return frequencies, documents


def write_supported_pairs(snapshot, output):
    words = {line.split("\t")[0] for line in VOCABULARY.read_text(encoding="utf-8").splitlines()}
    frequencies, documents = corpus_counts(snapshot, words)
    with output.open("wb") as target, gzip.GzipFile(filename="", mode="wb", fileobj=target, mtime=0) as out:
        kept = 0
        for (previous, following), count in sorted(frequencies.items()):
            if count >= 3 and documents[previous, following] >= 2:
                out.write(f"{previous}\t{following}\t{count}\n".encode("utf-8"))
                kept += 1
    print(f"{kept:,} supported word pairs")


def build_expanded(snapshot, dictionary, output):
    builder = import_module("build-typing-model")
    vocab, total = builder.khmer_word_counts(VOCABULARY)
    # A repeated dependent vowel signals a typing error in the base dictionary.
    # Accepting it as a new word would suppress the keyboard's duplicate-mark repair.
    def valid_addition(word):
        return builder.valid_khmer_word(word) and not any(
            a == b and "\u17b6" <= a <= "\u17c5" for a, b in zip(word, word[1:])
        )

    for word in dictionary.read_text(encoding="utf-8-sig").splitlines():
        if valid_addition(word):
            vocab.setdefault(word, 1)
    for line in (SCRIPTS / "km-expanded-headwords.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        if not valid_addition(line):
            raise ValueError(f"Invalid expanded headword {line!r}")
        vocab.setdefault(line, 1)

    frequencies, _ = corpus_counts(snapshot, vocab)
    rows = {}
    for (previous, word), count in frequencies.items():
        rows.setdefault(previous, {})[word] = count
    # Limit the scan on each keystroke and retain the most informative pairs
    # that fit the expanded model's on-device budget.
    pairs, totals = builder.khmer_pair_counts(vocab, rows, max_followers=192)
    builder.write_model("km", vocab, total, pairs, output, min_pair=0,
                        context_totals=totals, max_pairs=404_360)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--expanded-dictionary", type=Path, metavar="ICU_KHMERDICT")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if icu.ICU_VERSION != "78.3":
        parser.error(f"expected ICU 78.3, found {icu.ICU_VERSION}")
    if hashlib.sha256(args.snapshot.read_bytes()).hexdigest() != SNAPSHOT_SHA256:
        parser.error("snapshot hash differs from the pinned Khmer Wikipedia file")
    if args.expanded_dictionary:
        if hashlib.sha256(args.expanded_dictionary.read_bytes()).hexdigest() != ICU_DICTIONARY_SHA256:
            parser.error("dictionary hash differs from ICU 78.3 khmerdict.txt")
        build_expanded(args.snapshot, args.expanded_dictionary,
                       args.output or VOCABULARY.with_name("km-expanded.hextm"))
    else:
        write_supported_pairs(args.snapshot, args.output or SCRIPTS / "km-corpus-pairs.tsv.gz")


if __name__ == "__main__":
    main()
