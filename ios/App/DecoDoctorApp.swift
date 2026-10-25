import DecoPresentation
import SwiftUI

@main
struct DecoDoctorApp: App {
    private let startup: Result<AppDependencies, Error> = Result { try AppContainer.makeLive() }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case let .success(dependencies):
                RootView(dependencies: dependencies)
            case let .failure(error):
                StartupErrorView(message: error.localizedDescription)
            }
        }
    }
}
