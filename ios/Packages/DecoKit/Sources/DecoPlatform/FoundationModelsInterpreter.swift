import DecoDomain
import Foundation
import FoundationModels

/// Usa el modelo de Apple Intelligence para elegir, con el contexto de toda la receta, cuál de los
/// candidatos del matching corresponde a cada renglón. El esquema de salida se arma por receta:
/// cada renglón solo admite los IDs de sus candidatos o "ninguno", así que el modelo no puede
/// inventar un medicamento (ADR 0002).
public struct FoundationModelsInterpreter: PrescriptionInterpreter {
    static let none = "ninguno"

    static let instructions = """
        Ayudás a personal de farmacia a leer recetas médicas manuscritas de Argentina.
        Recibís renglones leídos por OCR, que suelen tener errores de letra, y para cada uno una \
        lista cerrada de opciones del vademécum. Elegí la opción que mejor corresponde al texto, \
        teniendo en cuenta la concentración, la forma farmacéutica y el resto de la receta. \
        Si el renglón no nombra un medicamento, elegí "ninguno". Nunca uses algo fuera de la lista.
        """

    public init() {}

    public func unavailabilityReason() async -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "es_AR")) ? nil : "El modelo no admite español en este dispositivo."
        case .unavailable(.deviceNotEligible):
            return "Este iPhone no es compatible con Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence está desactivado en Ajustes."
        case .unavailable(.modelNotReady):
            return "El modelo de Apple Intelligence todavía se está descargando."
        case .unavailable:
            return "El modelo de Apple Intelligence no está disponible."
        }
    }

    public func chooseMedications(for lines: [PrescriptionLine]) async throws -> [UUID: String?] {
        let properties = lines.enumerated().map { position, line in
            DynamicGenerationSchema.Property(
                name: Self.propertyName(position),
                schema: DynamicGenerationSchema(
                    name: "Opciones\(position)",
                    anyOf: line.candidates.map(\.medication.id) + [Self.none]
                )
            )
        }
        let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "Receta", properties: properties), dependencies: [])
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Self.prompt(for: lines),
            schema: schema,
            options: GenerationOptions(sampling: .greedy)
        )

        var choices: [UUID: String?] = [:]
        for (position, line) in lines.enumerated() {
            let chosen = try response.content.value(String.self, forProperty: Self.propertyName(position))
            choices[line.id] = .some(chosen == Self.none ? nil : chosen)
        }
        return choices
    }

    static func propertyName(_ position: Int) -> String { "renglon\(position)" }

    /// Solo texto OCR y nombres del diccionario: ningún dato del paciente.
    static func prompt(for lines: [PrescriptionLine]) -> String {
        lines.enumerated().map { position, line in
            let readings = line.recognized.candidates.prefix(3).map { "«\($0.text)»" }.joined(separator: ", ")
            let options = line.candidates.map { candidate in
                let brands = candidate.medication.brands.prefix(3).joined(separator: ", ")
                return "- \(candidate.medication.id): \(candidate.medication.generic)" + (brands.isEmpty ? "" : " (marcas: \(brands))")
            }.joined(separator: "\n")
            return "\(propertyName(position)) — lecturas OCR: \(readings)\nopciones:\n\(options)"
        }.joined(separator: "\n\n")
    }
}
