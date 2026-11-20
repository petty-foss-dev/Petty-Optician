import XCTest
@testable import PettyOptician

final class GlossaryLinkTests: XCTestCase {
    private func linked(_ raw: String, exam: ExamID, domain: String) throws -> [(String, GlossaryTerm)] {
        let index = try XCTUnwrap(GlossaryLinks.byExam[exam])
        var seen = Set<String>()
        let value = index.linking(AttributedString(raw), domain: domain, seen: &seen)
        return try value.runs.compactMap { run in
            guard let url = run.link else { return nil }
            return (String(value[run.range].characters), try XCTUnwrap(index.termsByID[url.lastPathComponent]))
        }
    }

    func testLongestTermWinsAndOrdinaryWordsKeepTheirMeaning() throws {
        let text = "Look up optical center or vertex distance. Do not add anything to the paperwork. Optical center."
        let pairs = try linked(text, exam: .abo, domain: "abo.optics")
        XCTAssertEqual(pairs.map(\.0), ["optical center", "vertex distance"])
        let terms = try linked("Verify an OR or an over-refraction.", exam: .ncle, domain: "ncle.refraction")
        XCTAssertEqual(terms.map(\.0), ["OR"])
    }

    func testBaseCurveDefinitionsDependOnExamAndDecentrationPrefersCanonicalEntry() throws {
        let abo = try linked("Base curve and decentration.", exam: .abo, domain: "abo.optics")
        XCTAssertEqual(abo.map { $0.1.term }, ["Base curve (spectacle lens)", "Decentration"])
        let ncle = try linked("Base curve.", exam: .ncle, domain: "ncle.fitting")
        XCTAssertEqual(ncle.first?.1.term, "Base curve (contact lens)")
    }

    func testMatchingPreservesTextAndEmphasisAcrossUnicodeAndAliases() throws {
        let index = try XCTUnwrap(GlossaryLinks.byExam[.abo])
        var seen = Set<String>()
        let input = try AttributedString(markdown: "👁 **Optical center** (OC) differs from optical centers.")
        let output = index.linking(input, domain: "abo.optics", seen: &seen)
        XCTAssertEqual(String(input.characters), String(output.characters))
        let linked = try XCTUnwrap(output.runs.first { $0.link != nil })
        XCTAssertTrue(linked.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        XCTAssertEqual(String(output[linked.range].characters), "Optical center")
        XCTAssertEqual(output.runs.filter { $0.link != nil }.count, 1)
        XCTAssertTrue(index.linking(AttributedString("OC"), domain: "abo.optics", seen: &seen).runs.allSatisfy { $0.link == nil })
        XCTAssertTrue(try self.linked("mycornealine", exam: .abo, domain: "abo.anatomy").isEmpty)
    }
}
