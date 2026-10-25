import DecoDomain
import Foundation
import Observation

@Observable
@MainActor
public final class HistoryViewModel {
    private(set) var records: [PrescriptionRecord] = []
    private(set) var errorMessage: String?

    private let listHistory: ListHistory
    private let deleteRecord: DeleteRecord

    public init(listHistory: ListHistory, deleteRecord: DeleteRecord) {
        self.listHistory = listHistory
        self.deleteRecord = deleteRecord
    }

    func load() async {
        do {
            records = try await listHistory()
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo cargar el historial: \(error.localizedDescription)"
        }
    }

    func delete(_ record: PrescriptionRecord) async {
        do {
            try await deleteRecord(id: record.id)
            records.removeAll { $0.id == record.id }
        } catch {
            errorMessage = "No se pudo borrar: \(error.localizedDescription)"
        }
    }
}
