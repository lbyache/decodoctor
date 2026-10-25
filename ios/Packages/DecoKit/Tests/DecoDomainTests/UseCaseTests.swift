import Foundation
import Testing
@testable import DecoDomain

@Suite struct ReadPrescriptionTests {
    let catalog = MedicationCatalog(dictionary: StaticMedicationDictionary(try! Shared.medications()))
    let prescription = [
        line("Dr. Juan Pérez"),
        line("Amoxicilna 500"),
        line("1 comp c/8 hs x 7 días"),
        line("Ibupirac 600 N° 1"),
    ]

    func read(interpreter: (any PrescriptionInterpreter)? = nil, corrections: any CorrectionStore = InMemoryCorrectionStore(), lines: [RecognizedLine]? = nil) async throws -> PrescriptionReading {
        let useCase = ReadPrescription(recognizer: FakeRecognizer(lines: lines ?? prescription), catalog: catalog,
                                       corrections: corrections, interpreter: interpreter)
        return try await useCase(imageData: Data())
    }

    @Test func splitsMedicationLinesFromTheRest() async throws {
        let reading = try await read()
        #expect(reading.medicationLines.map { $0.suggestion?.medication.id } == ["amoxicilina", "ibuprofeno"])
        #expect(reading.otherLines.map(\.bestText) == ["Dr. Juan Pérez", "1 comp c/8 hs x 7 días"])
        #expect(reading.interpretedBy == .matchingOnly)
    }

    @Test func takesPosologyFromTheNextLine() async throws {
        let reading = try await read()
        let amoxicillin = reading.medicationLines[0].dosage
        #expect(amoxicillin == Dosage(dose: "1 comprimido", everyHours: 8, days: 7))
        #expect(reading.medicationLines[1].dosage.boxes == 1)
    }

    @Test func modelCanReorderCandidatesButDisagreementLowersConfidence() async throws {
        let interpreter = FakeInterpreter { lines in
            // Elige el segundo candidato del primer renglón.
            [lines[0].id: lines[0].candidates.last?.medication.id]
        }
        // "Amoxidal" es marca de amoxicilina sola y, con "Duo", de la asociación: dos candidatos.
        let reading = try await read(interpreter: interpreter, lines: [line("Amoxidal 500")])
        let first = try #require(reading.medicationLines.first)
        #expect(first.suggestion?.medication.id == "amoxicilina-acido-clavulanico")
        // El modelo eligió contra el matching (que puntuaba más alto la otra opción): queda en baja
        // para que el empleado lo mire con atención.
        #expect(first.confidence == .low)
        #expect(reading.interpretedBy == .onDeviceModel)
    }

    @Test func modelCannotIntroduceAMedicationTheMatchingDidNotPropose() async throws {
        let interpreter = FakeInterpreter { lines in [lines[0].id: "sildenafil"] }
        let reading = try await read(interpreter: interpreter, lines: [line("Amoxicilina 500")])
        #expect(reading.medicationLines[0].suggestion?.medication.id == "amoxicilina")
    }

    @Test func modelSayingNoneLowersConfidence() async throws {
        let interpreter = FakeInterpreter { lines in [lines[0].id: String?.none] }
        let reading = try await read(interpreter: interpreter, lines: [line("Amoxicilina 500 mg")])
        #expect(reading.medicationLines[0].confidence == .medium)
    }

    @Test func unavailableOrFailingModelFallsBackToMatching() async throws {
        struct Boom: Error {}
        let unavailable = FakeInterpreter(reason: "Apple Intelligence desactivado") { _ in Issue.record("no debería llamarse"); return [:] }
        let failing = FakeInterpreter { _ in throw Boom() }
        #expect(try await read(interpreter: unavailable).interpretedBy == .matchingOnly)
        #expect(try await read(interpreter: failing).interpretedBy == .matchingOnly)
    }

    @Test func learnedCorrectionsWinOverFuzzyMatches() async throws {
        let corrections = InMemoryCorrectionStore()
        // El médico abrevia "Rivotril" como "Rivo" y el empleado lo corrigió antes.
        await corrections.recordCorrection(key: "rivo", medicationID: "clonazepam")
        let reading = try await read(corrections: corrections, lines: [line("Rivo 2 mg")])
        let first = try #require(reading.medicationLines.first?.suggestion)
        #expect(first.medication.id == "clonazepam")
        #expect(first.isLearned)
    }
}

@Suite struct ConfirmReadingTests {
    let medication = Medication(id: "amoxicilina", generic: "Amoxicilina")
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    func reading() -> PrescriptionReading {
        PrescriptionReading(createdAt: date, imageData: Data([1, 2, 3]), medicationLines: [
            PrescriptionLine(recognized: line("Amoxicilna 500", "Amoxicilina 500"), candidates: [], dosage: Dosage(), confidence: .high),
            PrescriptionLine(recognized: line("Xyzzz 10"), candidates: [], dosage: Dosage(), confidence: .low),
        ], otherLines: [], interpretedBy: .matchingOnly)
    }

    @Test func refusesToSaveWithUndecidedLines() async {
        let useCase = ConfirmReading(history: InMemoryHistoryRepository(), corrections: InMemoryCorrectionStore())
        let reading = reading()
        await #expect(throws: ConfirmReadingError.undecidedLines(count: 1)) {
            try await useCase(reading, decisions: [reading.medicationLines[0].id: .notAMedication], keepImage: false)
        }
    }

    @Test func savesRecordAndLearnsFromEveryReading() async throws {
        let history = InMemoryHistoryRepository()
        let corrections = InMemoryCorrectionStore()
        let useCase = ConfirmReading(history: history, corrections: corrections, clock: FixedClock(date: date))
        let reading = reading()
        let record = try await useCase(reading, decisions: [
            reading.medicationLines[0].id: .confirmed(medication, Dosage(everyHours: 8)),
            reading.medicationLines[1].id: .referToPharmacist,
        ], keepImage: false)

        #expect(record.status == .referredToPharmacist)
        #expect(record.items.map(\.medication.id) == ["amoxicilina"])
        #expect(record.referredTexts == ["Xyzzz 10"])
        #expect(record.imageData == nil)
        #expect(try await history.allRecords().count == 1)
        #expect(await corrections.learnedMedications(forKey: "amoxicilna") == ["amoxicilina": 1])
        #expect(await corrections.learnedMedications(forKey: "amoxicilina") == ["amoxicilina": 1])
    }

    @Test func keepsImageOnlyWhenAsked() async throws {
        let useCase = ConfirmReading(history: InMemoryHistoryRepository(), corrections: InMemoryCorrectionStore())
        let reading = reading()
        let decisions = Dictionary(uniqueKeysWithValues: reading.medicationLines.map { ($0.id, LineDecision.notAMedication) })
        let record = try await useCase(reading, decisions: decisions, keepImage: true)
        #expect(record.imageData == Data([1, 2, 3]))
        #expect(record.status == .confirmed)
    }
}

@Suite struct HistoryTests {
    @Test func purgeDeletesOnlyExpiredRecords() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = PrescriptionRecord(createdAt: now.addingTimeInterval(-40 * 86_400), status: .confirmed, items: [], referredTexts: [], imageData: nil)
        let recent = PrescriptionRecord(createdAt: now.addingTimeInterval(-2 * 86_400), status: .confirmed, items: [], referredTexts: [], imageData: nil)
        let history = InMemoryHistoryRepository(records: [old, recent])

        let deleted = try await PurgeExpiredHistory(history: history, clock: FixedClock(date: now))(retentionDays: 30)

        #expect(deleted == 1)
        #expect(try await ListHistory(history: history)().map(\.id) == [recent.id])
    }

    @Test func retentionIsClampedToTheAllowedRange() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = PrescriptionRecord(createdAt: now.addingTimeInterval(-86_400 * 1.5), status: .confirmed, items: [], referredTexts: [], imageData: nil)
        let history = InMemoryHistoryRepository(records: [yesterday])
        // 0 días se interpreta como 1: nunca se borra lo que se acaba de guardar.
        #expect(try await PurgeExpiredHistory(history: history, clock: FixedClock(date: now))(retentionDays: 0) == 1)
    }
}
