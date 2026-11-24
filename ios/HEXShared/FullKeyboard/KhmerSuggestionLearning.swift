import Foundation

/// Counts of completed Khmer words and short sequences, with no saved text runs.
nonisolated struct KhmerSuggestionLearning: Codable, Equatable, Sendable {
    private static let wordLimit = 128
    private static let followersLimit = 8
    private static let countLimit = 32

    private var words: [String: Int] = [:]
    private var pairs: [String: [String: Int]] = [:]
    private var triples: [String: [String: Int]]?

    var isEmpty: Bool { words.isEmpty }

    mutating func record(_ word: String, after previous: String?, precededBy earlier: String? = nil) {
        if let removed = Self.increment(word, in: &words, limit: Self.wordLimit) {
            pairs.removeValue(forKey: removed)
        }
        guard let previous, words[previous] != nil else { return }
        _ = Self.increment(word, in: &pairs[previous, default: [:]], limit: Self.followersLimit)
        guard let earlier, words[earlier] != nil else { return }
        let context = earlier + " " + previous
        var contexts = triples ?? [:]
        if contexts[context] == nil, contexts.count == Self.wordLimit,
           let leastUsed = contexts.min(by: {
               let a = $0.value.values.max() ?? 0
               let b = $1.value.values.max() ?? 0
               return a == b ? $0.key < $1.key : a < b
           })?.key {
            contexts.removeValue(forKey: leastUsed)
        }
        _ = Self.increment(word, in: &contexts[context, default: [:]], limit: Self.followersLimit)
        triples = contexts
    }

    var contextualFollowers: [String: [String]] {
        (triples ?? [:]).compactMapValues { counts in
            let ranked = Self.rankedWords(counts, prefix: "")
            return ranked.isEmpty ? nil : ranked
        }
    }

    func preferredWords(after previous: String? = nil, prefix: String = "") -> [String] {
        let counts = previous.map { pairs[$0] ?? [:] } ?? words
        return Self.rankedWords(counts, prefix: prefix)
    }

    private static func rankedWords(_ counts: [String: Int], prefix: String) -> [String] {
        return counts.filter { word, count in
            count >= 2 && word.utf16.starts(with: prefix.utf16)
        }.sorted { a, b in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map(\.key)
    }

    private static func increment(_ word: String, in counts: inout [String: Int], limit: Int) -> String? {
        let count = counts[word, default: 0]
        counts[word] = min(count, countLimit - 1) + 1
        guard counts.count > limit,
              let leastUsed = counts.filter({ $0.key != word }).min(by: {
                  $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value
              })?.key else { return nil }
        counts.removeValue(forKey: leastUsed)
        return leastUsed
    }
}
