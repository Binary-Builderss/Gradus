import SwiftUI

/// Assistenza e informazioni: contatto, termini, privacy, versione.
struct AboutView: View {
    let environment: AppEnvironment

    var body: some View {
        List {
            Section("Assistenza") {
                if let support = URL(string: "mailto:contactus@binarybuilders.dev") {
                    Link(destination: support) {
                        Label("Scrivici", systemImage: "envelope")
                    }
                }
            }
            Section("Informazioni legali") {
                Link(destination: environment.config.siteURL.appending(path: "termini")) {
                    Label("Termini di servizio", systemImage: "doc.text")
                }
                Link(destination: environment.config.siteURL.appending(path: "privacy")) {
                    Label("Informativa sulla privacy", systemImage: "hand.raised")
                }
            }
            Section {
                LabeledContent("Versione", value: version)
            }
        }
        .navigationTitle("Assistenza e informazioni")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}
