import LocalAuthentication
import Observation

/// Bloqueo opcional con Face ID / Touch ID / código del dispositivo.
@Observable
@MainActor
final class PrivacyLock {
    private(set) var isLocked: Bool

    init(locked: Bool) {
        isLocked = locked
    }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lock() { isLocked = true }

    func unlock() async {
        let context = LAContext()
        let success = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Desbloqueá para ver las recetas")) ?? false
        if success { isLocked = false }
    }
}
