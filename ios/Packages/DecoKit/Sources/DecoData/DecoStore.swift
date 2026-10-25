import DecoDomain
import Foundation
import SwiftData

// Los @Model no salen de esta capa: hacia afuera viajan structs del dominio.

@Model
final class RecordModel {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var statusRaw: String
    /// `[ConfirmedItem]` en JSON: la lista es chica y siempre se lee entera.
    var itemsJSON: Data
    var referredTexts: [String]
    @Attribute(.externalStorage) var imageData: Data?

    init(id: UUID, createdAt: Date, statusRaw: String, itemsJSON: Data, referredTexts: [String], imageData: Data?) {
        self.id = id
        self.createdAt = createdAt
        self.statusRaw = statusRaw
        self.itemsJSON = itemsJSON
        self.referredTexts = referredTexts
        self.imageData = imageData
    }
}

@Model
final class CorrectionModel {
    var key: String
    var medicationID: String
    var count: Int
    var updatedAt: Date

    init(key: String, medicationID: String, count: Int, updatedAt: Date) {
        self.key = key
        self.medicationID = medicationID
        self.count = count
        self.updatedAt = updatedAt
    }
}

public enum DecoStore {
    /// Contenedor local, sin CloudKit: los datos de salud no salen del dispositivo.
    /// Los archivos quedan protegidos por el entitlement `default-data-protection` (Complete).
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "DecoDoctor",
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: RecordModel.self, CorrectionModel.self, configurations: configuration)
    }

    public static func makeHistoryRepository(container: ModelContainer) -> any HistoryRepository {
        SwiftDataHistoryRepository(modelContainer: container)
    }

    public static func makeCorrectionStore(container: ModelContainer) -> any CorrectionStore {
        SwiftDataCorrectionStore(modelContainer: container)
    }
}

@ModelActor
actor SwiftDataHistoryRepository: HistoryRepository {
    func save(_ record: PrescriptionRecord) throws {
        modelContext.insert(RecordModel(
            id: record.id,
            createdAt: record.createdAt,
            statusRaw: record.status.rawValue,
            itemsJSON: try JSONEncoder().encode(record.items),
            referredTexts: record.referredTexts,
            imageData: record.imageData
        ))
        try modelContext.save()
    }

    func allRecords() throws -> [PrescriptionRecord] {
        try modelContext.fetch(FetchDescriptor<RecordModel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .map { model in
                PrescriptionRecord(
                    id: model.id,
                    createdAt: model.createdAt,
                    status: RecordStatus(rawValue: model.statusRaw) ?? .referredToPharmacist,
                    items: (try? JSONDecoder().decode([ConfirmedItem].self, from: model.itemsJSON)) ?? [],
                    referredTexts: model.referredTexts,
                    imageData: model.imageData
                )
            }
    }

    func delete(id: UUID) throws {
        try modelContext.delete(model: RecordModel.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    func deleteRecords(olderThan date: Date) throws -> Int {
        let expired = try modelContext.fetchCount(FetchDescriptor<RecordModel>(predicate: #Predicate { $0.createdAt < date }))
        try modelContext.delete(model: RecordModel.self, where: #Predicate { $0.createdAt < date })
        try modelContext.save()
        return expired
    }
}

@ModelActor
actor SwiftDataCorrectionStore: CorrectionStore {
    func learnedMedications(forKey key: String) throws -> [String: Int] {
        let rows = try modelContext.fetch(FetchDescriptor<CorrectionModel>(predicate: #Predicate { $0.key == key }))
        return Dictionary(rows.map { ($0.medicationID, $0.count) }, uniquingKeysWith: +)
    }

    func recordCorrection(key: String, medicationID: String) throws {
        let existing = try modelContext.fetch(FetchDescriptor<CorrectionModel>(
            predicate: #Predicate { $0.key == key && $0.medicationID == medicationID }
        )).first
        if let existing {
            existing.count += 1
            existing.updatedAt = Date()
        } else {
            modelContext.insert(CorrectionModel(key: key, medicationID: medicationID, count: 1, updatedAt: Date()))
        }
        try modelContext.save()
    }

    func learnedKeys(limit: Int) throws -> [String] {
        var descriptor = FetchDescriptor<CorrectionModel>(sortBy: [SortDescriptor(\.count, order: .reverse)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(\.key)
    }
}
