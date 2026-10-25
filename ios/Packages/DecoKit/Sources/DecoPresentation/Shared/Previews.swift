import DecoDomain
import Foundation

extension AppDependencies {
    /// Dependencias en memoria para previews de SwiftUI: lectura simulada, sin Vision ni modelo.
    public static func preview(lines: [String] = ["Dr. Juan Pérez", "Amoxicilna 500", "1 comp c/8 hs x 7 días", "Ibupirac 600 N° 1", "Rivo 2 mg"]) -> AppDependencies {
        let medications = [
            Medication(id: "amoxicilina", generic: "Amoxicilina", brands: ["Amoxidal"]),
            Medication(id: "amoxicilina-acido-clavulanico", generic: "Amoxicilina + Ácido clavulánico", brands: ["Amoxidal Duo"]),
            Medication(id: "ibuprofeno", generic: "Ibuprofeno", brands: ["Ibupirac", "Actron"]),
            Medication(id: "clonazepam", generic: "Clonazepam", brands: ["Rivotril"]),
        ]
        let catalog = MedicationCatalog(dictionary: StaticMedicationDictionary(medications))
        let corrections = InMemoryCorrectionStore()
        let history = InMemoryHistoryRepository()
        let recognized = lines.enumerated().map { position, text in
            RecognizedLine(candidates: [TextCandidate(text: text, confidence: 0.5)],
                           box: NormalizedBox(x: 0.08, y: 0.12 + Double(position) * 0.12, width: 0.7, height: 0.08))
        }
        return AppDependencies(
            readPrescription: ReadPrescription(recognizer: PreviewRecognizer(lines: recognized), catalog: catalog,
                                               corrections: corrections, interpreter: nil),
            confirmReading: ConfirmReading(history: history, corrections: corrections),
            searchMedications: SearchMedications(catalog: catalog),
            listHistory: ListHistory(history: history),
            deleteRecord: DeleteRecord(history: history),
            purgeHistory: PurgeExpiredHistory(history: history),
            interpreterUnavailableReason: { "Vista previa: sin modelo" },
            dictionaryDescription: "Diccionario de prueba"
        )
    }
}

struct PreviewRecognizer: TextRecognizer {
    let lines: [RecognizedLine]
    func recognizeLines(in imageData: Data, customWords: [String]) -> [RecognizedLine] { lines }
}
