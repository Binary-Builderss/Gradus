import Domain
import GRDB
import SwiftUI

/// Un account disattivato non vede l'app: solo la schermata per riattivarlo o uscire (come sul web).
struct AccountGate<Content: View>: View {
    let environment: AppEnvironment
    let userID: UUID
    @ViewBuilder var content: Content
    @State private var status = AccountStatus()
    @State private var postponedName = false

    var body: some View {
        Group {
            if status.disabled {
                DisabledAccountView(environment: environment, userID: userID)
            } else if status.needsName && !postponedName {
                NamePromptView(environment: environment, userID: userID, initial: "", canSkip: true) { postponedName = true }
            } else {
                content
            }
        }
        .task { await status.watch(database: environment.database, userID: userID) }
    }
}
