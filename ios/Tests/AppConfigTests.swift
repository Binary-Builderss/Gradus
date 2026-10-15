import Foundation
import Testing

@testable import Gradus

struct AppConfigTests {
    private let valid: [String: Any] = [
        "SupabaseURL": "https://abc.supabase.co", "SupabaseAnonKey": "sb_publishable_xxx",
        "SiteURL": "https://gradus-trainer.binarybuilders.dev",
    ]

    @Test("configurazione completa")
    func complete() {
        let config = AppConfig(info: valid)
        #expect(config?.supabaseURL.host() == "abc.supabase.co")
        #expect(config?.siteURL.host() == "gradus-trainer.binarybuilders.dev")
    }

    @Test("manca un valore, è vuoto o è ancora il segnaposto: nessuna configurazione")
    func incomplete() {
        for key in ["SupabaseURL", "SupabaseAnonKey", "SiteURL"] {
            var info = valid
            info[key] = ""
            #expect(AppConfig(info: info) == nil)
            info[key] = nil
            #expect(AppConfig(info: info) == nil)
        }
        var placeholder = valid
        placeholder["SupabaseAnonKey"] = "INCOLLA_QUI_LA_CHIAVE_PUBLISHABLE"
        #expect(AppConfig(info: placeholder) == nil)
        #expect(AppConfig(info: nil) == nil)
    }
}
