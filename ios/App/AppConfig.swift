import Foundation

/// Indirizzo e chiave pubblica del server, letti da Info.plist (che li prende da `Config/Secrets.xcconfig`).
struct AppConfig: Equatable, Sendable {
    var supabaseURL: URL
    var supabaseAnonKey: String
    /// Il sito del coach: da lì l'atleta sceglie la password dall'invito e la recupera.
    var siteURL: URL

    /// Nil se manca qualcosa: l'app lo dice invece di cadere.
    init?(info: [String: Any]?) {
        func value(_ key: String) -> String? {
            let v = (info?[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return v?.isEmpty == false ? v : nil
        }
        guard let url = value("SupabaseURL").flatMap(URL.init(string:)), url.scheme?.hasPrefix("http") == true,
            let key = value("SupabaseAnonKey"), !key.hasPrefix("INCOLLA"),
            let site = value("SiteURL").flatMap(URL.init(string:))
        else { return nil }
        self.supabaseURL = url
        self.supabaseAnonKey = key
        self.siteURL = site
    }

    static var current: AppConfig? { AppConfig(info: Bundle.main.infoDictionary) }
}
