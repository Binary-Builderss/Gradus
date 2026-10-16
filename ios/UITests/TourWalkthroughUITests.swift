import XCTest

/// Percorre la guida nel simulatore e salva uno screenshot per passo (per controllare a occhio dove cade l'evidenziazione).
/// Si salta da sola. Per lanciarla serve il Supabase locale con `Scripts/seed_local.py` e l'app costruita contro di esso:
///
///     TEST_RUNNER_GRADUS_UI_USER=atleta@prova.local TEST_RUNNER_GRADUS_UI_PASSWORD=<password del seed> \
///     TEST_RUNNER_GRADUS_UI_OUT=/tmp/guida xcodebuild test -scheme GradusUI \
///       SUPABASE_URL='http:/$()/127.0.0.1:54321' SUPABASE_ANON_KEY=<publishable locale> …
final class TourWalkthroughUITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    func testGuideWalkthrough() throws {
        let user = try XCTUnwrap(env["GRADUS_UI_USER"].flatMap { $0.isEmpty ? nil : $0 }, "senza credenziali di prova la prova si salta")
        let password = try XCTUnwrap(env["GRADUS_UI_PASSWORD"], "manca GRADUS_UI_PASSWORD")
        let out = env["GRADUS_UI_OUT"] ?? "/tmp/guida"
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments = ["-tourSeen", "NO"]  // la guida parte da sola anche se un'esecuzione precedente l'ha già vista
        app.launch()

        // Accesso con l'account di prova del database locale (se una prova precedente ha lasciato la sessione nel
        // portachiavi, che sopravvive alla disinstallazione, si è già dentro).
        let email = app.textFields.firstMatch
        if email.waitForExistence(timeout: 15) {
            email.tap()
            email.typeText(user)
            let secure = app.secureTextFields.firstMatch
            secure.tap()
            secure.typeText(password)
            app.buttons["Accedi"].firstMatch.tap()
        }

        // La guida parte da sola la prima volta.
        let next = app.buttons["Avanti"]
        XCTAssertTrue(next.waitForExistence(timeout: 30), "la guida non è partita")
        var index = 1
        while true {
            Thread.sleep(forTimeInterval: 0.8)  // il tempo di cambiare scheda e di far arrivare le posizioni
            save(app, "\(out)/passo-\(String(format: "%02d", index)).png")
            if app.buttons["Fine"].exists { break }
            app.buttons["Avanti"].tap()
            index += 1
            if index > 40 { XCTFail("la guida non finisce"); break }
        }
        app.buttons["Fine"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        save(app, "\(out)/fine.png")
        XCTAssertFalse(app.buttons["Avanti"].exists)
    }

    private func save(_ app: XCUIApplication, _ path: String) {
        let data = app.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: path))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
