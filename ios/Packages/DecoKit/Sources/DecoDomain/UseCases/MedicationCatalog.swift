/// Carga el diccionario una sola vez y comparte el índice entre los casos de uso.
public actor MedicationCatalog {
    private let dictionary: any MedicationDictionary
    private var cached: MedicationIndex?

    public init(dictionary: any MedicationDictionary) {
        self.dictionary = dictionary
    }

    public func index() async throws -> MedicationIndex {
        if let cached { return cached }
        let index = MedicationIndex(medications: try await dictionary.allMedications())
        cached = index
        return index
    }
}

/// Búsqueda manual cuando el medicamento correcto no está entre los candidatos.
public struct SearchMedications: Sendable {
    private let catalog: MedicationCatalog

    public init(catalog: MedicationCatalog) {
        self.catalog = catalog
    }

    public func callAsFunction(_ query: String) async throws -> [Medication] {
        guard query.trimmingCharacters(in: .whitespaces).count >= 3 else { return [] }
        return try await catalog.index().search(query)
    }
}
