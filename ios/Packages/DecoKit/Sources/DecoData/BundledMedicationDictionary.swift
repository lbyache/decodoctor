import DecoDomain
import Foundation

/// Diccionario incluido en la app (`Resources/medicamentos.json`, copia de `shared/dictionary`).
public struct BundledMedicationDictionary: MedicationDictionary {
    struct File: Decodable {
        let version: String
        let source: String
        let medications: [Medication]
    }

    private let url: URL

    public init(url: URL? = nil) {
        self.url = url ?? Bundle.module.url(forResource: "medicamentos", withExtension: "json")!
    }

    public func allMedications() async throws -> [Medication] {
        try load().medications
    }

    /// Versión y origen, para mostrar en Ajustes.
    public func metadata() throws -> (version: String, source: String) {
        let file = try load()
        return (file.version, file.source)
    }

    private func load() throws -> File {
        try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
    }
}
