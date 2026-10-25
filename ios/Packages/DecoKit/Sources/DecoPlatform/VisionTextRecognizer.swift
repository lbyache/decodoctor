import DecoDomain
import Foundation
import Vision

/// OCR en el dispositivo con Vision. Devuelve hasta 5 lecturas por renglón para que el matching
/// pueda elegir la que coincide con el diccionario (ADR 0002).
public struct VisionTextRecognizer: TextRecognizer {
    static let alternativesPerLine = 5
    /// Tope de vocabulario personalizado; las palabras aprendidas van primero.
    static let maxCustomWords = 2_000

    public init() {}

    public func recognizeLines(in imageData: Data, customWords: [String]) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        // `customWords` solo se aplica con la corrección de idioma activada.
        request.usesLanguageCorrection = true
        request.customWords = Array(customWords.prefix(Self.maxCustomWords))
        let spanish = request.supportedRecognitionLanguages.filter { $0.languageCode == .spanish }
        request.recognitionLanguages = spanish.isEmpty ? [Locale.Language(identifier: "es")] : spanish

        let observations = try await request.perform(on: imageData)
        return observations
            // Vision usa origen abajo a la izquierda: mayor `y` = más arriba en la hoja.
            .sorted { $0.boundingBox.cgRect.maxY > $1.boundingBox.cgRect.maxY }
            .map { observation in
                let rect = observation.boundingBox.cgRect
                return RecognizedLine(
                    candidates: observation.topCandidates(Self.alternativesPerLine).map {
                        TextCandidate(text: $0.string, confidence: Double($0.confidence))
                    },
                    box: NormalizedBox(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
                )
            }
            .filter { !$0.candidates.isEmpty }
    }
}
