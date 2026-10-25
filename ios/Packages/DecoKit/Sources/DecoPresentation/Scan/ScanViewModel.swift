import DecoDomain
import Foundation
import Observation

@Observable
@MainActor
public final class ScanViewModel {
    enum State {
        case idle
        case reading
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Lectura lista para revisar; la vista la presenta como hoja.
    var review: ReviewViewModel?
    /// Por qué no se usa Foundation Models en este dispositivo (`nil` si se usa).
    private(set) var interpreterNote: String?

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func loadInterpreterStatus() async {
        interpreterNote = await dependencies.interpreterUnavailableReason()
    }

    func read(imageData: Data) async {
        state = .reading
        do {
            let reading = try await dependencies.readPrescription(imageData: imageData)
            state = .idle
            if reading.medicationLines.isEmpty {
                state = .failed("No se reconoció ningún medicamento. Probá con más luz, la hoja derecha y sin sombras, o derivá la receta al farmacéutico.")
                return
            }
            review = ReviewViewModel(reading: reading, confirmReading: dependencies.confirmReading,
                                     searchMedications: dependencies.searchMedications)
        } catch {
            state = .failed("No se pudo leer la imagen: \(error.localizedDescription)")
        }
    }
}
