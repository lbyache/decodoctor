import Foundation

public enum ConfirmReadingError: Error, Equatable {
    /// Hay renglones sin decidir: la app nunca guarda una lectura que el empleado no revisó entera.
    case undecidedLines(count: Int)
}

/// Guarda la receta revisada en el historial y aprende de lo que confirmó el empleado.
public struct ConfirmReading: Sendable {
    private let history: any HistoryRepository
    private let corrections: any CorrectionStore
    private let clock: any Clock

    public init(history: any HistoryRepository, corrections: any CorrectionStore, clock: any Clock = SystemClock()) {
        self.history = history
        self.corrections = corrections
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(_ reading: PrescriptionReading, decisions: [UUID: LineDecision], keepImage: Bool) async throws -> PrescriptionRecord {
        let undecided = reading.medicationLines.filter { decisions[$0.id] == nil }.count
        guard undecided == 0 else { throw ConfirmReadingError.undecidedLines(count: undecided) }

        var items: [ConfirmedItem] = []
        var referred: [String] = []
        for line in reading.medicationLines {
            switch decisions[line.id] {
            case let .confirmed(medication, dosage):
                items.append(ConfirmedItem(medication: medication, dosage: dosage, sourceText: line.recognized.bestText))
                try await learn(line: line, medicationID: medication.id)
            case .referToPharmacist:
                referred.append(line.recognized.bestText)
            case .notAMedication, nil:
                break
            }
        }

        let record = PrescriptionRecord(
            createdAt: clock.now(),
            status: referred.isEmpty ? .confirmed : .referredToPharmacist,
            items: items,
            referredTexts: referred,
            imageData: keepImage ? reading.imageData : nil
        )
        try await history.save(record)
        return record
    }

    /// Asocia cada lectura OCR del renglón con el medicamento confirmado.
    private func learn(line: PrescriptionLine, medicationID: String) async throws {
        let keys = Set(line.recognized.candidates.map { TextNormalizer.correctionKey($0.text) }).filter { !$0.isEmpty }
        for key in keys {
            try await corrections.recordCorrection(key: key, medicationID: medicationID)
        }
    }
}

public struct ListHistory: Sendable {
    private let history: any HistoryRepository

    public init(history: any HistoryRepository) {
        self.history = history
    }

    public func callAsFunction() async throws -> [PrescriptionRecord] {
        try await history.allRecords().sorted { $0.createdAt > $1.createdAt }
    }
}

public struct DeleteRecord: Sendable {
    private let history: any HistoryRepository

    public init(history: any HistoryRepository) {
        self.history = history
    }

    public func callAsFunction(id: UUID) async throws {
        try await history.delete(id: id)
    }
}

/// Borrado automático: el historial no guarda recetas más allá de la retención elegida.
public struct PurgeExpiredHistory: Sendable {
    public static let defaultRetentionDays = 30
    public static let retentionRange = 1...90

    private let history: any HistoryRepository
    private let clock: any Clock

    public init(history: any HistoryRepository, clock: any Clock = SystemClock()) {
        self.history = history
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(retentionDays: Int) async throws -> Int {
        let days = min(max(retentionDays, Self.retentionRange.lowerBound), Self.retentionRange.upperBound)
        let cutoff = clock.now().addingTimeInterval(-Double(days) * 86_400)
        return try await history.deleteRecords(olderThan: cutoff)
    }
}
