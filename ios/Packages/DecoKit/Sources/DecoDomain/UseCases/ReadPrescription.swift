import Foundation

/// Foto → renglones con medicamentos candidatos, posología y confianza. No guarda nada: el
/// resultado pasa siempre por la revisión del empleado (`ConfirmReading`).
public struct ReadPrescription: Sendable {
    /// Ventana de contexto del modelo: no se le mandan más renglones que estos (ADR 0002).
    static let maxLinesForModel = 12

    private let recognizer: any TextRecognizer
    private let catalog: MedicationCatalog
    private let corrections: any CorrectionStore
    private let interpreter: (any PrescriptionInterpreter)?
    private let clock: any Clock

    public init(recognizer: any TextRecognizer, catalog: MedicationCatalog, corrections: any CorrectionStore, interpreter: (any PrescriptionInterpreter)?, clock: any Clock = SystemClock()) {
        self.recognizer = recognizer
        self.catalog = catalog
        self.corrections = corrections
        self.interpreter = interpreter
        self.clock = clock
    }

    public func callAsFunction(imageData: Data) async throws -> PrescriptionReading {
        let index = try await catalog.index()
        let learnedWords = try await corrections.learnedKeys(limit: 200)
        let recognized = try await recognizer.recognizeLines(in: imageData, customWords: learnedWords + index.vocabulary)

        var medicationLines: [PrescriptionLine] = []
        var otherLines: [RecognizedLine] = []
        for (position, line) in recognized.enumerated() {
            let candidates = try await applyLearning(to: index.candidates(for: line), line: line, index: index)
            guard !candidates.isEmpty else {
                otherLines.append(line)
                continue
            }
            var dosage = DosageParser.parse(line.bestText)
            // La posología suele ir en el renglón de abajo ("1 comp c/8 hs x 7 días").
            if let next = recognized[safe: position + 1], index.candidates(for: next).isEmpty {
                dosage = dosage.filling(from: DosageParser.parse(next.bestText))
            }
            medicationLines.append(PrescriptionLine(
                recognized: line,
                candidates: candidates,
                dosage: dosage,
                confidence: ConfidencePolicy.confidence(for: candidates)
            ))
        }

        let (lines, kind) = await interpret(medicationLines)
        return PrescriptionReading(
            createdAt: clock.now(),
            imageData: imageData,
            medicationLines: lines,
            otherLines: otherLines,
            interpretedBy: kind
        )
    }

    /// Las correcciones confirmadas antes ponen a ese medicamento arriba con puntaje alto.
    private func applyLearning(to candidates: [MedicationCandidate], line: RecognizedLine, index: MedicationIndex) async throws -> [MedicationCandidate] {
        var byID = Dictionary(candidates.map { ($0.medication.id, $0) }, uniquingKeysWith: { first, _ in first })
        for reading in line.candidates {
            let key = TextNormalizer.correctionKey(reading.text)
            guard !key.isEmpty else { continue }
            for (medicationID, times) in try await corrections.learnedMedications(forKey: key) {
                guard let medication = index.medication(id: medicationID) else { continue }
                let score = min(0.99, 0.95 + 0.01 * Double(times))
                if score > (byID[medicationID]?.score ?? 0) {
                    byID[medicationID] = MedicationCandidate(medication: medication, score: score, matchedName: medication.generic, isLearned: true)
                }
            }
        }
        return byID.values.sorted { $0.score != $1.score ? $0.score > $1.score : $0.medication.id < $1.medication.id }
    }

    /// Le pide al modelo que elija entre los candidatos. Cualquier problema → se queda el matching.
    private func interpret(_ lines: [PrescriptionLine]) async -> ([PrescriptionLine], InterpreterKind) {
        guard let interpreter, !lines.isEmpty, await interpreter.unavailabilityReason() == nil,
              let choices = try? await interpreter.chooseMedications(for: Array(lines.prefix(Self.maxLinesForModel)))
        else { return (lines, .matchingOnly) }

        let interpreted = lines.map { line -> PrescriptionLine in
            guard let choice = choices[line.id] else { return line }
            guard let chosenID = choice else {
                return PrescriptionLine(id: line.id, recognized: line.recognized, candidates: line.candidates, dosage: line.dosage,
                                        confidence: ConfidencePolicy.confidence(for: line.candidates, modelRejected: true))
            }
            // Validación de dominio: el modelo no puede traer un medicamento que el matching no propuso.
            guard let chosenIndex = line.candidates.firstIndex(where: { $0.medication.id == chosenID }) else { return line }
            var reordered = line.candidates
            let chosen = reordered.remove(at: chosenIndex)
            reordered.insert(chosen, at: 0)
            return PrescriptionLine(id: line.id, recognized: line.recognized, candidates: reordered, dosage: line.dosage,
                                    confidence: ConfidencePolicy.confidence(for: reordered, chosenByModel: chosenIndex != 0))
        }
        return (interpreted, .onDeviceModel)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
