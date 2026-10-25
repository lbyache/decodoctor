import DecoDomain
import Foundation

/// Lo que la UI necesita del resto de la app: solo casos de uso del dominio.
/// Lo arma el composition root (`AppContainer`) o, en previews, `AppDependencies.preview`.
public struct AppDependencies: Sendable {
    public let readPrescription: ReadPrescription
    public let confirmReading: ConfirmReading
    public let searchMedications: SearchMedications
    public let listHistory: ListHistory
    public let deleteRecord: DeleteRecord
    public let purgeHistory: PurgeExpiredHistory
    /// `nil` si Foundation Models está disponible; si no, el motivo para mostrar.
    public let interpreterUnavailableReason: @Sendable () async -> String?
    /// Versión y origen del diccionario, para Ajustes.
    public let dictionaryDescription: String

    public init(readPrescription: ReadPrescription, confirmReading: ConfirmReading, searchMedications: SearchMedications,
                listHistory: ListHistory, deleteRecord: DeleteRecord, purgeHistory: PurgeExpiredHistory,
                interpreterUnavailableReason: @escaping @Sendable () async -> String?, dictionaryDescription: String) {
        self.readPrescription = readPrescription
        self.confirmReading = confirmReading
        self.searchMedications = searchMedications
        self.listHistory = listHistory
        self.deleteRecord = deleteRecord
        self.purgeHistory = purgeHistory
        self.interpreterUnavailableReason = interpreterUnavailableReason
        self.dictionaryDescription = dictionaryDescription
    }
}

/// Preferencias del usuario (no sensibles), en `UserDefaults` vía `@AppStorage`.
enum SettingsKey {
    static let retentionDays = "retentionDays"
    static let keepImages = "keepImages"
    static let requireUnlock = "requireUnlock"
}
