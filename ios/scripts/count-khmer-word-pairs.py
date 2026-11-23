#!/usr/bin/env python3
"""Count known adjacent words in the 2023-11-01 Khmer Wikipedia snapshot.

Download 20231101.km/train-00000-of-00001.parquet from wikimedia/wikipedia at
b04c8d1ceb2f5cd4588862100d08de323dccfbaa. Requires pyarrow and PyICU with
ICU 78.3 (its Khmer dictionary determines the boundaries). Run from any cwd:
    python3 ios/scripts/count-khmer-word-pairs.py path/to/snapshot.parquet
Only needed to regenerate the compressed counts, not to build the app.
"""

import argparse
import gzip
import hashlib
from collections import Counter
from pathlib import Path

import icu
import pyarrow.parquet as parquet

SCRIPTS = Path(__file__).resolve().parent
VOCABULARY = SCRIPTS.parent / "HEXKeyboard/TypingModel/km-autocomplete.tsv"
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--output", type=Path, default=SCRIPTS / "km-corpus-pairs.tsv.gz")
    args = parser.parse_args()
    if icu.ICU_VERSION != "78.3":
        parser.error(f"expected ICU 78.3, found {icu.ICU_VERSION}")
    if hashlib.sha256(args.snapshot.read_bytes()).hexdigest() != SNAPSHOT_SHA256:
        parser.error("snapshot hash differs from the pinned Khmer Wikipedia file")
    words = {line.split("\t")[0] for line in VOCABULARY.read_text(encoding="utf-8").splitlines()}
    breaker = icu.BreakIterator.createWordInstance(icu.Locale("km"))
    frequencies = Counter()
    documents = Counter()
    articles = parquet.ParquetFile(args.snapshot)
    for batch in articles.iter_batches(batch_size=64, columns=["text"]):
        for article in batch.column(0).to_pylist():
            counts = article_pairs(article, words, breaker)
            documents.update(counts.keys())
            # Repeated names and templates on a single page should carry little weight.
            frequencies.update({pair: min(count, 3) for pair, count in counts.items()})
    with args.output.open("wb") as target, gzip.GzipFile(filename="", mode="wb", fileobj=target, mtime=0) as out:
        kept = 0
        for (previous, following), count in sorted(frequencies.items()):
            if count >= 3 and documents[previous, following] >= 2:
                out.write(f"{previous}\t{following}\t{count}\n".encode("utf-8"))
                kept += 1
    print(f"{articles.metadata.num_rows:,} articles, {kept:,} supported word pairs")


if __name__ == "__main__":
    main()
