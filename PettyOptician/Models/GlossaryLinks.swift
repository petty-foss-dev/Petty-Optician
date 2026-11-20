import Foundation

struct GlossaryLinks: Sendable {
    static let byExam = Dictionary(uniqueKeysWithValues: ExamID.allCases.map { exam in
        (exam, GlossaryLinks(terms: ContentLibrary.shared.glossary(for: exam)))
    })

    private struct Candidate: Sendable {
        let term: GlossaryTerm
        let canonical: Bool
    }

    private let candidates: [String: [Candidate]]
    private let pattern: NSRegularExpression
    let termsByID: [String: GlossaryTerm]

    init(terms: [GlossaryTerm]) {
        termsByID = Dictionary(uniqueKeysWithValues: terms.map { ($0.id, $0) })
        var choices: [String: [Candidate]] = [:]
        var expressions = Set<String>()
        for term in terms {
            let title = term.term.components(separatedBy: " (")[0]
            for name in Set([title] + (term.aliases ?? [])) where name.count > 1 {
                // Short all-caps notation such as OR and ADD must not match ordinary prose.
                let exactCase = name == name.uppercased()
                if name == "Add" { continue }
                var spellings = [name]
                if name.lowercased().hasSuffix("lens") { spellings.append(name + "es") }
                for spelling in spellings {
                    let key = Self.normalize(spelling)
                    choices[key, default: []].append(Candidate(term: term, canonical: name == title))
                    let literal = NSRegularExpression.escapedPattern(for: Self.normalize(spelling, lowercase: false))
                        .replacingOccurrences(of: "'", with: "['’]")
                        .replacingOccurrences(of: "-", with: "[-‐‑–]")
                    expressions.insert(exactCase ? literal : "(?i:\(literal))")
                }
            }
        }
        candidates = choices
        // Sort by literal length so “back vertex distance” wins over any shorter prefix.
        let alternatives = expressions.sorted { lhs, rhs in
            func length(_ value: String) -> Int { value.count - (value.hasPrefix("(?i:") ? 5 : 0) }
            let a = length(lhs), b = length(rhs)
            return a == b ? lhs < rhs : a > b
        }.joined(separator: "|")
        pattern = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{N}_])")
    }

    private static func normalize(_ value: String, lowercase: Bool = true) -> String {
        var text = value.replacingOccurrences(of: "’", with: "'")
        for dash in ["‐", "‑", "–"] { text = text.replacingOccurrences(of: dash, with: "-") }
        return lowercase ? text.lowercased() : text
    }

    func linking(_ source: AttributedString, domain: String, seen: inout Set<String>) -> AttributedString {
        var text = source
        let plain = String(source.characters)
        for match in pattern.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            guard let range = Range(match.range, in: plain),
                  let options = candidates[Self.normalize(String(plain[range]))] else { continue }
            let canonical = options.filter(\.canonical)
            let pool = canonical.isEmpty ? options : canonical
            let local = pool.filter { $0.term.domains.contains(domain) }
            let best = local.isEmpty ? pool : local
            guard let term = best.first?.term, best.allSatisfy({ $0.term.id == term.id }),
                  !seen.contains(term.id),
                  let lower = AttributedString.Index(range.lowerBound, within: text),
                  let upper = AttributedString.Index(range.upperBound, within: text),
                  let url = URL(string: "petty-glossary://term/\(term.id)") else { continue }
            seen.insert(term.id)
            text[lower..<upper].link = url
        }
        return text
    }
}
