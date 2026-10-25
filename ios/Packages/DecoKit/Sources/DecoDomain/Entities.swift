import Foundation

/// Una droga (o asociación) del diccionario. La concentración y la posología se leen del texto
/// de la receta; no se modelan como entradas distintas (ADR 0003).
public struct Medication: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let generic: String
    public let brands: [String]
    public let strengths: [String]
    public let forms: [String]

    public init(id: String, generic: String, brands: [String] = [], strengths: [String] = [], forms: [String] = []) {
        self.id = id
        self.generic = generic
        self.brands = brands
        self.strengths = strengths
        self.forms = forms
    }

    /// Nombres contra los que se compara el texto leído: genérico primero, después las marcas.
    public var searchableNames: [String] { [generic] + brands }
}

/// Una lectura posible del OCR para un renglón, con la confianza que reporta el reconocedor (0…1).
public struct TextCandidate: Hashable, Sendable, Codable {
    public let text: String
    public let confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
    }
}

/// Rectángulo normalizado (0…1) con origen arriba a la izquierda, como lo dibuja SwiftUI.
public struct NormalizedBox: Hashable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Un renglón tal como lo leyó el OCR: hasta N lecturas alternativas, la mejor primero.
public struct RecognizedLine: Hashable, Sendable, Codable {
    public let candidates: [TextCandidate]
    public let box: NormalizedBox?

    public init(candidates: [TextCandidate], box: NormalizedBox? = nil) {
        self.candidates = candidates
        self.box = box
    }

    public var bestText: String { candidates.first?.text ?? "" }
}

/// Posología detectada en el texto. Los campos ausentes no se pudieron leer.
public struct Dosage: Hashable, Sendable, Codable {
    public var strength: String?
    public var dose: String?
    public var everyHours: Int?
    public var days: Int?
    public var boxes: Int?

    public init(strength: String? = nil, dose: String? = nil, everyHours: Int? = nil, days: Int? = nil, boxes: Int? = nil) {
        self.strength = strength
        self.dose = dose
        self.everyHours = everyHours
        self.days = days
        self.boxes = boxes
    }

    public var isEmpty: Bool {
        strength == nil && dose == nil && everyHours == nil && days == nil && boxes == nil
    }

    /// Resumen legible: "500 mg · 1 comprimido cada 8 h · 7 días · 2 cajas".
    public var summary: String {
        var parts: [String] = []
        if let strength { parts.append(strength) }
        var intake = dose ?? ""
        if let everyHours {
            let frequency = everyHours == 24 ? "por día" : "cada \(everyHours) h"
            intake = intake.isEmpty ? frequency : "\(intake) \(frequency)"
        }
        if !intake.isEmpty { parts.append(intake) }
        if let days { parts.append(days == 1 ? "1 día" : "\(days) días") }
        if let boxes { parts.append(boxes == 1 ? "1 caja" : "\(boxes) cajas") }
        return parts.joined(separator: " · ")
    }

    /// Completa los campos vacíos con los de otra lectura (p. ej. el renglón siguiente).
    public func filling(from other: Dosage) -> Dosage {
        Dosage(
            strength: strength ?? other.strength,
            dose: dose ?? other.dose,
            everyHours: everyHours ?? other.everyHours,
            days: days ?? other.days,
            boxes: boxes ?? other.boxes
        )
    }
}

public enum Confidence: String, Sendable, Codable, Comparable, CaseIterable {
    case low, medium, high

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        let order: [Confidence] = [.low, .medium, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Un medicamento propuesto para un renglón, con su puntaje de similitud (0…1).
public struct MedicationCandidate: Hashable, Sendable, Codable {
    public let medication: Medication
    public let score: Double
    /// Qué texto del renglón coincidió (genérico o marca), para mostrarlo.
    public let matchedName: String
    /// Sube por una corrección confirmada antes.
    public let isLearned: Bool

    public init(medication: Medication, score: Double, matchedName: String, isLearned: Bool = false) {
        self.medication = medication
        self.score = score
        self.matchedName = matchedName
        self.isLearned = isLearned
    }
}

/// Quién eligió la sugerencia principal de cada renglón.
public enum InterpreterKind: String, Sendable, Codable {
    /// Foundation Models eligió entre los candidatos.
    case onDeviceModel
    /// Solo el puntaje del matching (dispositivo sin Apple Intelligence o modelo no disponible).
    case matchingOnly
}

/// Un renglón de la receta ya analizado.
public struct PrescriptionLine: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let recognized: RecognizedLine
    /// Ordenados: el primero es la sugerencia principal.
    public let candidates: [MedicationCandidate]
    public let dosage: Dosage
    public let confidence: Confidence?

    public init(id: UUID = UUID(), recognized: RecognizedLine, candidates: [MedicationCandidate], dosage: Dosage, confidence: Confidence?) {
        self.id = id
        self.recognized = recognized
        self.candidates = candidates
        self.dosage = dosage
        self.confidence = confidence
    }

    public var suggestion: MedicationCandidate? { candidates.first }
    public var isMedication: Bool { !candidates.isEmpty }
}

/// Resultado de leer una receta, antes de que el empleado la confirme.
public struct PrescriptionReading: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let imageData: Data
    /// Renglones con al menos un medicamento candidato.
    public let medicationLines: [PrescriptionLine]
    /// El resto del texto (encabezado, fechas, diagnóstico), para contexto.
    public let otherLines: [RecognizedLine]
    public let interpretedBy: InterpreterKind

    public init(id: UUID = UUID(), createdAt: Date, imageData: Data, medicationLines: [PrescriptionLine], otherLines: [RecognizedLine], interpretedBy: InterpreterKind) {
        self.id = id
        self.createdAt = createdAt
        self.imageData = imageData
        self.medicationLines = medicationLines
        self.otherLines = otherLines
        self.interpretedBy = interpretedBy
    }
}

/// Lo que decide el empleado para cada renglón.
public enum LineDecision: Hashable, Sendable {
    case confirmed(Medication, Dosage)
    case notAMedication
    case referToPharmacist
}

/// Un medicamento confirmado en una receta guardada.
public struct ConfirmedItem: Hashable, Sendable, Codable {
    public let medication: Medication
    public let dosage: Dosage
    public let sourceText: String

    public init(medication: Medication, dosage: Dosage, sourceText: String) {
        self.medication = medication
        self.dosage = dosage
        self.sourceText = sourceText
    }
}

public enum RecordStatus: String, Sendable, Codable {
    /// Todos los renglones quedaron confirmados por el empleado.
    case confirmed
    /// Al menos un renglón quedó para el farmacéutico.
    case referredToPharmacist
}

/// Una receta guardada en el historial.
public struct PrescriptionRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let status: RecordStatus
    public let items: [ConfirmedItem]
    /// Textos de los renglones derivados al farmacéutico.
    public let referredTexts: [String]
    public let imageData: Data?

    public init(id: UUID = UUID(), createdAt: Date, status: RecordStatus, items: [ConfirmedItem], referredTexts: [String], imageData: Data?) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.items = items
        self.referredTexts = referredTexts
        self.imageData = imageData
    }
}
