import Foundation

/// Supertonic voices at most ~70 characters at a time and restarts its intonation for each piece, so the split points are
/// what a listener hears as pauses. This breaks text where a reader would breathe — sentence ends, then clause
/// punctuation, then before a conjunction — and keeps pieces evenly sized so no stray word is left dangling.
enum SpeechPhrases {
    struct Phrase: Equatable, Sendable {
        let text: String
        /// Seconds of silence to add after this phrase.
        let pause: Double
    }

    static let maxLength = 70
    static let sentencePause = 0.32
    static let clausePause = 0.14
    static let joinPause = 0.03

    private static let abbreviations = ["e.g.", "i.e.", "vs.", "etc.", "Dr.", "approx.", "no.", "Fig."]
    private static let conjunctions = ["and", "or", "but", "so", "because", "which", "while", "when", "where", "if", "then", "that", "with", "without", "than", "to", "for", "from", "into"]

    static func split(_ text: String, maxLength: Int = maxLength) -> [Phrase] {
        var phrases: [Phrase] = []
        for line in text.components(separatedBy: .newlines) {
            let line = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !line.isEmpty else { continue }
            for sentence in sentences(line) {
                let pieces = pieces(of: sentence, maxLength: maxLength)
                for (index, piece) in pieces.enumerated() {
                    let last = index == pieces.count - 1
                    phrases.append(Phrase(text: piece.text, pause: last ? sentencePause : piece.endsClause ? clausePause : joinPause))
                }
            }
        }
        return phrases
    }

    /// Supertonic pads each clip with up to ~1.3 s of near-silence, which would otherwise be heard as a stall between
    /// phrases. Keeps the voiced part plus a short margin, with a few-ms fade so the cut can't click.
    static func trimSilence(_ samples: [Float], sampleRate: Double, threshold: Float = 0.006) -> [Float] {
        let frame = max(1, Int(sampleRate * 0.01))
        let loud = stride(from: 0, to: samples.count, by: frame).filter { start in
            let window = samples[start..<min(samples.count, start + frame)]
            return sqrt(window.reduce(0) { $0 + $1 * $1 } / Float(window.count)) > threshold
        }
        guard let first = loud.first, let last = loud.last else { return [] }
        let lead = Int(sampleRate * 0.03), tail = Int(sampleRate * 0.08)
        var clip = Array(samples[max(0, first - lead)..<min(samples.count, last + frame + tail)])
        let fade = min(clip.count / 2, Int(sampleRate * 0.005))
        for i in 0..<fade {
            let gain = Float(i) / Float(fade)
            clip[i] *= gain
            clip[clip.count - 1 - i] *= gain
        }
        return clip
    }

    private static func sentences(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        let words = line.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() {
            current += current.isEmpty ? word : " " + word
            let ends = word.last.map { ".!?".contains($0) } ?? false
            let abbreviation = abbreviations.contains { word.caseInsensitiveCompare($0) == .orderedSame }
            let nextStartsUpper = index + 1 < words.count && words[index + 1].first.map { $0.isUppercase || $0.isNumber || $0 == "(" } == true
            if ends && !abbreviation && (index + 1 == words.count || nextStartsUpper) {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private struct Piece {
        let text: String
        let endsClause: Bool
    }

    /// Splits recursively, choosing for each cut the most natural boundary near an even share of the remaining text.
    private static func pieces(of sentence: String, maxLength: Int) -> [Piece] {
        guard sentence.count > maxLength else { return [Piece(text: sentence, endsClause: false)] }
        let words = sentence.split(separator: " ").map(String.init)
        let count = sentence.count
        let target = Double(count) / Double((count + maxLength - 1) / maxLength)

        var best: (index: Int, score: Double, clause: Bool)?
        var length = 0
        for index in 0..<(words.count - 1) {
            length += (index == 0 ? 0 : 1) + words[index].count
            let rest = count - length - 1
            guard length <= maxLength, length >= 8, rest >= 8 else { continue }
            let (strength, clause) = boundary(after: words[index], before: words[index + 1])
            let score = strength * 30 - abs(Double(length) - target)
            if best == nil || score > best!.score { best = (index, score, clause) }
        }
        guard let cut = best ?? fallback(words, maxLength: maxLength) else { return [Piece(text: sentence, endsClause: false)] }
        let head = words[...cut.index].joined(separator: " ")
        let tail = words[(cut.index + 1)...].joined(separator: " ")
        return [Piece(text: head, endsClause: cut.clause)] + pieces(of: tail, maxLength: maxLength)
    }

    private static func fallback(_ words: [String], maxLength: Int) -> (index: Int, score: Double, clause: Bool)? {
        var length = 0
        var last: Int?
        for index in 0..<(words.count - 1) {
            length += (index == 0 ? 0 : 1) + words[index].count
            if length <= maxLength { last = index } else { break }
        }
        return last.map { ($0, 0, false) }
    }

    private static func boundary(after word: String, before next: String) -> (strength: Double, clause: Bool) {
        if let mark = word.last, ";:".contains(mark) { return (5, true) }
        if ["—", "–", "-"].contains(next) || word.hasSuffix("—") { return (4, true) }
        if word.hasSuffix(",") || word.hasSuffix(")") { return (3, true) }
        if next.hasPrefix("(") { return (3, true) }
        if conjunctions.contains(next.lowercased()) { return (2, false) }
        return (0, false)
    }
}
