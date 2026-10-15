import SwiftUI

@main
struct GradusApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            if let environment {
                RootView(environment: environment)
            } else {
                MissingConfigView()
            }
        }
    }
}
