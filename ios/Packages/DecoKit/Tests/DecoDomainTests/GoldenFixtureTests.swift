import Foundation
import Testing
@testable import DecoDomain

/// Casos dorados de `shared/fixtures`: los mismos que va a correr Android.
@Suite struct GoldenFixtureTests {
    struct MatchingCase: Decodable, CustomTestStringConvertible, Sendable {
        let name: String
        let ocr: [String]
        let expectedMedicationID: String?
        var testDescription: String { name }
    }

    struct DosageCase: Decodable, CustomTestStringConvertible, Sendable {
        let text: String
        let strength: String?
        let dose: String?
        let everyHours: Int?
        let days: Int?
        let boxes: Int?
        var testDescription: String { text }
    }

    struct File<Case: Decodable>: Decodable { let cases: [Case] }

    static let matchingCases = try! JSONDecoder().decode(File<MatchingCase>.self, from: Shared.data("fixtures/matching.json")).cases
    static let dosageCases = try! JSONDecoder().decode(File<DosageCase>.self, from: Shared.data("fixtures/dosage.json")).cases

    @Test(arguments: matchingCases)
    func matching(_ fixture: MatchingCase) {
        let recognized = RecognizedLine(candidates: fixture.ocr.map { TextCandidate(text: $0, confidence: 0.5) })
        let candidates = Shared.index.candidates(for: recognized)
        #expect(candidates.first?.medication.id == fixture.expectedMedicationID,
                "candidatos: \(candidates.map { "\($0.medication.id) \($0.score)" })")
    }

    @Test(arguments: dosageCases)
    func dosage(_ fixture: DosageCase) {
        let expected = Dosage(strength: fixture.strength, dose: fixture.dose, everyHours: fixture.everyHours, days: fixture.days, boxes: fixture.boxes)
        #expect(DosageParser.parse(fixture.text) == expected)
    }
}
