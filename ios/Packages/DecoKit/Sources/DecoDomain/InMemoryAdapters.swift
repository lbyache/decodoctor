import Foundation

/// Implementaciones en memoria de los puertos de persistencia. Sirven para tests, previews de
/// SwiftUI y como modelo de referencia para Android.
public actor InMemoryCorrectionStore: CorrectionStore {
    private var counts: [String: [String: Int]] = [:]

    public init() {}

    public func learnedMedications(forKey key: String) -> [String: Int] { counts[key] ?? [:] }

    public func recordCorrection(key: String, medicationID: String) {
        counts[key, default: [:]][medicationID, default: 0] += 1
    }

    public func learnedKeys(limit: Int) -> [String] { Array(counts.keys.sorted().prefix(limit)) }
}

public actor InMemoryHistoryRepository: HistoryRepository {
    private var records: [UUID: PrescriptionRecord] = [:]

    public init(records: [PrescriptionRecord] = []) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    public func save(_ record: PrescriptionRecord) { records[record.id] = record }
    public func allRecords() -> [PrescriptionRecord] { Array(records.values) }
    public func delete(id: UUID) { records[id] = nil }

    public func deleteRecords(olderThan date: Date) -> Int {
        let expired = records.values.filter { $0.createdAt < date }.map(\.id)
        expired.forEach { records[$0] = nil }
        return expired.count
    }
}

public struct StaticMedicationDictionary: MedicationDictionary {
    private let medications: [Medication]

    public init(_ medications: [Medication]) {
        self.medications = medications
    }

    public func allMedications() -> [Medication] { medications }
}
