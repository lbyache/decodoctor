import DecoDomain
import SwiftUI

/// Búsqueda manual en el diccionario, tolerante a errores de tipeo.
struct MedicationSearchView: View {
    let initialQuery: String
    let search: (String) async -> [Medication]
    let onSelect: (Medication) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Medication] = []

    var body: some View {
        NavigationStack {
            List(results) { medication in
                Button {
                    onSelect(medication)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(medication.generic)
                        if !medication.brands.isEmpty {
                            Text(medication.brands.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if results.isEmpty, query.count >= 3 {
                    ContentUnavailableView("Sin resultados", systemImage: "magnifyingglass",
                                           description: Text("Si no está en el diccionario, derivá el renglón al farmacéutico."))
                }
            }
            .searchable(text: $query, prompt: "Droga o marca")
            .task(id: query) {
                // Pequeña espera para no buscar en cada tecla.
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                results = await search(query)
            }
            .onAppear { query = TextNormalizer.nameWords(initialQuery).joined(separator: " ") }
            .navigationTitle("Buscar medicamento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }
}
