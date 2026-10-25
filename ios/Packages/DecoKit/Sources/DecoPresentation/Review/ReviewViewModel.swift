import DecoDomain
import Foundation
import Observation

/// Revisión de una lectura: el empleado decide renglón por renglón. Nada se guarda hasta que
/// todos los renglones tienen una decisión explícita.
@Observable
@MainActor
public final class ReviewViewModel: Identifiable {
    public enum Choice: Hashable {
        case undecided
        case medication(Medication)
        case notAMedication
        case referToPharmacist
    }

    public nonisolated let id = UUID()
    let reading: PrescriptionReading
    private(set) var choices: [UUID: Choice]
    var dosages: [UUID: Dosage]
    var selectedLineID: UUID?
    private(set) var savedRecord: PrescriptionRecord?
    private(set) var errorMessage: String?
    private(set) var isSaving = false

    private let confirmReading: ConfirmReading
    private let searchMedications: SearchMedications

    public init(reading: PrescriptionReading, confirmReading: ConfirmReading, searchMedications: SearchMedications) {
        self.reading = reading
        self.confirmReading = confirmReading
        self.searchMedications = searchMedications
        self.choices = Dictionary(uniqueKeysWithValues: reading.medicationLines.map { ($0.id, .undecided) })
        self.dosages = Dictionary(uniqueKeysWithValues: reading.medicationLines.map { ($0.id, $0.dosage) })
        self.selectedLineID = reading.medicationLines.first?.id
    }

    var lines: [PrescriptionLine] { reading.medicationLines }
    var undecidedCount: Int { choices.values.filter { $0 == .undecided }.count }
    var canSave: Bool { undecidedCount == 0 && !isSaving && savedRecord == nil }
    var highConfidencePendingCount: Int {
        lines.filter { $0.confidence == .high && choices[$0.id] == .undecided }.count
    }

    func choice(for line: PrescriptionLine) -> Choice { choices[line.id] ?? .undecided }

    func choose(_ choice: Choice, for line: PrescriptionLine) {
        choices[line.id] = choice
        selectedLineID = line.id
    }

    /// Atajo: acepta la sugerencia de los renglones con confianza alta que siguen sin decidir.
    func acceptHighConfidenceSuggestions() {
        for line in lines where line.confidence == .high && choices[line.id] == .undecided {
            if let suggestion = line.suggestion { choices[line.id] = .medication(suggestion.medication) }
        }
    }

    func search(_ query: String) async -> [Medication] {
        (try? await searchMedications(query)) ?? []
    }

    func save(keepImage: Bool) async {
        isSaving = true
        defer { isSaving = false }
        let decisions = Dictionary(uniqueKeysWithValues: lines.compactMap { line -> (UUID, LineDecision)? in
            switch choices[line.id] {
            case let .medication(medication): (line.id, .confirmed(medication, dosages[line.id] ?? line.dosage))
            case .notAMedication: (line.id, .notAMedication)
            case .referToPharmacist: (line.id, .referToPharmacist)
            case .undecided, nil: nil
            }
        })
        do {
            savedRecord = try await confirmReading(reading, decisions: decisions, keepImage: keepImage)
            errorMessage = nil
        } catch ConfirmReadingError.undecidedLines(let count) {
            errorMessage = "Faltan decidir \(count) renglones."
        } catch {
            errorMessage = "No se pudo guardar: \(error.localizedDescription)"
        }
    }
}
