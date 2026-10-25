import CoreGraphics
import CoreText
import DecoDomain
import Foundation
import FoundationModels
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DecoPlatform

/// Pruebas de integración con los frameworks reales de Apple (corren en macOS y en el simulador).
/// La calidad con letra manuscrita real se mide aparte, con fotos anonimizadas (ADR 0002).
@Suite struct PlatformTests {
    /// Imagen PNG con renglones de texto impreso, de arriba hacia abajo.
    static func renderedImage(lines: [String]) throws -> Data {
        let width = 1200, lineHeight = 90, height = lineHeight * (lines.count + 1)
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
        for (position, text) in lines.enumerated() {
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ])
            context.textPosition = CGPoint(x: 40, y: height - lineHeight * (position + 1))
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    @Test func visionReadsLinesTopToBottomWithBoxes() async throws {
        let image = try Self.renderedImage(lines: ["Amoxicilina 500 mg", "1 comp cada 8 horas"])
        let lines = try await VisionTextRecognizer().recognizeLines(in: image, customWords: ["Amoxicilina"])

        #expect(lines.count == 2)
        #expect(lines.first?.bestText.lowercased().contains("amoxicilina") == true)
        let first = try #require(lines.first?.box), second = try #require(lines.last?.box)
        #expect(first.y < second.y, "origen arriba a la izquierda")
        #expect((0...1).contains(first.x) && first.width > 0)
    }

    @Test func promptCarriesOnlyOCRTextAndDictionaryNames() {
        let medication = Medication(id: "ibuprofeno", generic: "Ibuprofeno", brands: ["Ibupirac"])
        let line = PrescriptionLine(
            recognized: RecognizedLine(candidates: [TextCandidate(text: "Ibupirac 600", confidence: 0.4)]),
            candidates: [MedicationCandidate(medication: medication, score: 0.98, matchedName: "Ibupirac")],
            dosage: Dosage(), confidence: .high)
        let prompt = FoundationModelsInterpreter.prompt(for: [line])
        #expect(prompt.contains("renglon0"))
        #expect(prompt.contains("«Ibupirac 600»"))
        #expect(prompt.contains("- ibuprofeno: Ibuprofeno (marcas: Ibupirac)"))
    }

    /// Solo corre donde Apple Intelligence está disponible; si no, se saltea.
    @Test(.enabled(if: SystemLanguageModel.default.isAvailable))
    func modelOnlyAnswersWithOfferedIDs() async throws {
        let amoxicillin = Medication(id: "amoxicilina", generic: "Amoxicilina", brands: ["Amoxidal"])
        let combo = Medication(id: "amoxicilina-acido-clavulanico", generic: "Amoxicilina + Ácido clavulánico", brands: ["Amoxidal Duo"])
        let line = PrescriptionLine(
            recognized: RecognizedLine(candidates: [TextCandidate(text: "Amoxidal duo 875/125", confidence: 0.4)]),
            candidates: [MedicationCandidate(medication: amoxicillin, score: 0.95, matchedName: "Amoxidal"),
                         MedicationCandidate(medication: combo, score: 0.94, matchedName: "Amoxidal Duo")],
            dosage: Dosage(), confidence: .medium)

        let choices = try await FoundationModelsInterpreter().chooseMedications(for: [line])
        let chosen = try #require(choices[line.id])
        #expect(chosen == nil || [amoxicillin.id, combo.id].contains(chosen!))
    }
}
