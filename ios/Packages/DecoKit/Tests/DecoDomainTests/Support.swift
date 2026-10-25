import Foundation
@testable import DecoDomain

/// Archivos de `shared/` (contratos con Android), leídos desde el repo.
enum Shared {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DecoDomainTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // DecoKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // raíz del repo
        .appendingPathComponent("shared")

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(path))
    }

    static func medications() throws -> [Medication] {
        struct File: Decodable { let medications: [Medication] }
        return try JSONDecoder().decode(File.self, from: data("dictionary/medicamentos.json")).medications
    }

    static let index: MedicationIndex = try! MedicationIndex(medications: medications())
}

func line(_ readings: String...) -> RecognizedLine {
    RecognizedLine(candidates: readings.map { TextCandidate(text: $0, confidence: 0.5) })
}

struct FakeRecognizer: TextRecognizer {
    let lines: [RecognizedLine]
    func recognizeLines(in imageData: Data, customWords: [String]) -> [RecognizedLine] { lines }
}

struct FakeInterpreter: PrescriptionInterpreter {
    var reason: String?
    var choose: @Sendable ([PrescriptionLine]) throws -> [UUID: String?]

    func unavailabilityReason() -> String? { reason }
    func chooseMedications(for lines: [PrescriptionLine]) throws -> [UUID: String?] { try choose(lines) }
}

struct FixedClock: Clock {
    var date: Date
    func now() -> Date { date }
}
