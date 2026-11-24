import Foundation

/// Counts of completed Khmer words and adjacent pairs, with no saved text runs.
nonisolated struct KhmerSuggestionLearning: Codable, Equatable, Sendable {
    private static let wordLimit = 128
    private static let followersLimit = 8
    private static let countLimit = 32

    private var words: [String: Int] = [:]
    private var pairs: [String: [String: Int]] = [:]

    var isEmpty: Bool { words.isEmpty }

    mutating func record(_ word: String, after previous: String?) {
        if let removed = Self.increment(word, in: &words, limit: Self.wordLimit) {
            pairs.removeValue(forKey: removed)
        }
        guard let previous, words[previous] != nil else { return }
        _ = Self.increment(word, in: &pairs[previous, default: [:]], limit: Self.followersLimit)
    }

    func preferredWords(after previous: String? = nil, prefix: String = "") -> [String] {
        let counts = previous.map { pairs[$0] ?? [:] } ?? words
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
