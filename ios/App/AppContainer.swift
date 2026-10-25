import DecoData
import DecoDomain
import DecoPlatform
import DecoPresentation
import Foundation

/// Composition root: el único lugar que conoce las implementaciones concretas
/// y las conecta con los puertos del dominio.
enum AppContainer {
    static func makeLive() throws -> AppDependencies {
        let container = try DecoStore.makeContainer()
        let dictionary = BundledMedicationDictionary()
        let catalog = MedicationCatalog(dictionary: dictionary)
        let corrections = DecoStore.makeCorrectionStore(container: container)
        let history = DecoStore.makeHistoryRepository(container: container)
        let interpreter = FoundationModelsInterpreter()
        let metadata = try dictionary.metadata()

        return AppDependencies(
            readPrescription: ReadPrescription(
                recognizer: VisionTextRecognizer(),
                catalog: catalog,
                corrections: corrections,
                interpreter: interpreter
            ),
            confirmReading: ConfirmReading(history: history, corrections: corrections),
            searchMedications: SearchMedications(catalog: catalog),
            listHistory: ListHistory(history: history),
            deleteRecord: DeleteRecord(history: history),
            purgeHistory: PurgeExpiredHistory(history: history),
            interpreterUnavailableReason: { await interpreter.unavailabilityReason() },
            dictionaryDescription: metadata.version
        )
    }
}
