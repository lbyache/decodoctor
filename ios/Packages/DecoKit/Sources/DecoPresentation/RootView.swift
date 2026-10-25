import DecoDomain
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.retentionDays) private var retentionDays = PurgeExpiredHistory.defaultRetentionDays
    @AppStorage(SettingsKey.requireUnlock) private var requireUnlock = false
    @State private var privacyLock: PrivacyLock

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let requiresUnlock = UserDefaults.standard.bool(forKey: SettingsKey.requireUnlock)
        _privacyLock = State(initialValue: PrivacyLock(locked: requiresUnlock && PrivacyLock.isAvailable))
    }

    public var body: some View {
        TabView {
            Tab("Leer", systemImage: "doc.text.viewfinder") { ScanView(dependencies: dependencies) }
            Tab("Historial", systemImage: "clock") { HistoryView(dependencies: dependencies) }
            Tab("Ajustes", systemImage: "gearshape") { SettingsView(dependencies: dependencies) }
        }
        .overlay {
            if privacyLock.isLocked {
                LockedView { Task { await privacyLock.unlock() } }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                Task { try? await dependencies.purgeHistory(retentionDays: retentionDays) }
            case .background:
                if requireUnlock && PrivacyLock.isAvailable { privacyLock.lock() }
            default:
                break
            }
        }
    }
}

private struct LockedView: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.largeTitle)
                Text("DecoDoctor está bloqueado").font(.headline)
                Button("Desbloquear", action: onUnlock).buttonStyle(.borderedProminent)
            }
        }
        .task { onUnlock() }
    }
}

/// Se muestra si la app no pudo abrir su base de datos.
public struct StartupErrorView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        ContentUnavailableView("No se pudo iniciar DecoDoctor", systemImage: "exclamationmark.triangle", description: Text(message))
    }
}

#Preview {
    RootView(dependencies: .preview())
}
