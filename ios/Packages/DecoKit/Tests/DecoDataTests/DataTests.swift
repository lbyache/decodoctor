import DecoDomain
import Foundation
import Testing
@testable import DecoData

@Suite struct DictionaryTests {
    /// La copia empaquetada tiene que ser idéntica a `shared/dictionary/medicamentos.json`,
    /// que es la que usa Android.
    @Test func bundledCopyMatchesSharedSource() throws {
        let shared = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/dictionary/medicamentos.json")
        let bundled = try #require(Bundle.module.url(forResource: "medicamentos", withExtension: "json"))
        #expect(try Data(contentsOf: bundled) == Data(contentsOf: shared))
    }

    @Test func loadsMedicationsWithUniqueIDs() async throws {
        let dictionary = BundledMedicationDictionary()
        let medications = try await dictionary.allMedications()
        #expect(medications.count >= 50)
        #expect(Set(medications.map(\.id)).count == medications.count)
        #expect(try dictionary.metadata().version.isEmpty == false)
    }
}

@Suite struct StoreTests {
    let container = try! DecoStore.makeContainer(inMemory: true)

    @Test func historyRoundTripAndPurge() async throws {
        let history = DecoStore.makeHistoryRepository(container: container)
        let now = Date()
        let item = ConfirmedItem(medication: Medication(id: "ibuprofeno", generic: "Ibuprofeno"),
                                 dosage: Dosage(strength: "600 mg", everyHours: 8), sourceText: "Ibupirac 600")
        let recent = PrescriptionRecord(createdAt: now, status: .confirmed, items: [item], referredTexts: [], imageData: Data([9]))
        let old = PrescriptionRecord(createdAt: now.addingTimeInterval(-90 * 86_400), status: .referredToPharmacist,
                                     items: [], referredTexts: ["Xyz"], imageData: nil)
        try await history.save(recent)
        try await history.save(old)

        let loaded = try await history.allRecords()
        #expect(loaded.map(\.id) == [recent.id, old.id])
        #expect(loaded.first?.items == [item])
        #expect(loaded.first?.imageData == Data([9]))

        #expect(try await history.deleteRecords(olderThan: now.addingTimeInterval(-30 * 86_400)) == 1)
        try await history.delete(id: recent.id)
        #expect(try await history.allRecords().isEmpty)
    }

    @Test func correctionsAccumulate() async throws {
        let corrections = DecoStore.makeCorrectionStore(container: container)
        try await corrections.recordCorrection(key: "rivo", medicationID: "clonazepam")
        try await corrections.recordCorrection(key: "rivo", medicationID: "clonazepam")
        try await corrections.recordCorrection(key: "amoxi", medicationID: "amoxicilina")

        #expect(try await corrections.learnedMedications(forKey: "rivo") == ["clonazepam": 2])
        #expect(try await corrections.learnedKeys(limit: 1) == ["rivo"])
    }
}
