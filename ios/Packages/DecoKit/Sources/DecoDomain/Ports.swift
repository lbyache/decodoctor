import Foundation

/// Lee el texto de una imagen. En iOS lo implementa Vision; en Android, ML Kit.
public protocol TextRecognizer: Sendable {
    /// - Parameter customWords: vocabulario que el reconocedor debe favorecer (nombres de medicamentos).
    /// - Returns: renglones de arriba hacia abajo, cada uno con sus lecturas alternativas.
    func recognizeLines(in imageData: Data, customWords: [String]) async throws -> [RecognizedLine]
}

/// Fuente del diccionario de medicamentos.
public protocol MedicationDictionary: Sendable {
    func allMedications() async throws -> [Medication]
}

/// Elige, para cada renglón, el mejor candidato usando el contexto de toda la receta.
/// Solo puede devolver IDs que ya están entre los candidatos de ese renglón.
public protocol PrescriptionInterpreter: Sendable {
    /// `nil` si se puede usar; si no, un motivo legible ("Apple Intelligence está desactivado").
    func unavailabilityReason() async -> String?
    /// - Returns: para cada renglón, el ID elegido o `nil` si el modelo cree que no es un medicamento.
    ///   Los renglones que falten en el resultado conservan el orden del matching.
    func chooseMedications(for lines: [PrescriptionLine]) async throws -> [UUID: String?]
}

/// Correcciones confirmadas por el empleado: "este texto era este medicamento".
public protocol CorrectionStore: Sendable {
    /// Medicamentos asociados a un texto normalizado, con cuántas veces se confirmaron.
    func learnedMedications(forKey key: String) async throws -> [String: Int]
    func recordCorrection(key: String, medicationID: String) async throws
    /// Textos aprendidos, para sumarlos al vocabulario del OCR.
    func learnedKeys(limit: Int) async throws -> [String]
}

public protocol HistoryRepository: Sendable {
    func save(_ record: PrescriptionRecord) async throws
    func allRecords() async throws -> [PrescriptionRecord]
    func delete(id: UUID) async throws
    /// Borra los registros anteriores a la fecha. Devuelve cuántos borró.
    @discardableResult
    func deleteRecords(olderThan date: Date) async throws -> Int
}

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
