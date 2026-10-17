import Foundation
import Supabase

/// `RemoteAPI` sopra supabase-swift. Usa solo la chiave pubblica e la sessione dell'utente: le policy RLS fanno il resto.
struct SupabaseRemote: RemoteAPI {
    let client: SupabaseClient

    func fetchPage(table: SyncTable, since: String?, offset: Int, limit: Int) async throws -> Data {
        var query = client.from(table.rawValue).select()
        if let since { query = query.gte("updated_at", value: since) }
        return try await query
            .order("updated_at", ascending: true)
            .order("id", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .data
    }

    func fetchBranding() async throws -> Data {
        try await client.from("coach_branding").select().execute().data
    }

    func fetchIDs(table: SyncTable) async throws -> Data {
        try await client.from(table.rawValue).select("id").limit(10_000).execute().data
    }

    func upsert(table: SyncTable, rows: Data) async throws {
        let values = try JSONDecoder().decode([AnyJSON].self, from: rows)
        try await client.from(table.rawValue).upsert(values, onConflict: "id", returning: .minimal).execute()
    }

    func updateName(userID: UUID, name: String) async throws {
        try await client.from("profiles").update(["full_name": name]).eq("id", value: userID.uuidString).execute()
    }

    func setNutritionConsent(userID: UUID, at date: Date?, version: String?) async throws {
        let at: AnyJSON = date.map { .string(ISO8601DateFormatter().string(from: $0)) } ?? .null
        let versionValue: AnyJSON = version.map { .string($0) } ?? .null
        try await client.from("profiles")
            .update(["nutrition_consent_at": at, "nutrition_consent_version": versionValue])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    func withdrawNutritionConsent() async throws {
        try await client.rpc("withdraw_nutrition_consent").execute()
    }

    func setAccountDisabled(userID: UUID, disabled: Bool) async throws {
        let value: AnyJSON = disabled ? .string(ISO8601DateFormatter().string(from: Date())) : .null
        try await client.from("profiles").update(["disabled_at": value]).eq("id", value: userID.uuidString).execute()
    }

    func deleteAccount(confirm: String) async throws {
        do {
            try await client.functions.invoke("delete-account", options: FunctionInvokeOptions(body: ["confirm": confirm]))
        } catch FunctionsError.httpError(_, let data) {
            struct Payload: Decodable { var error: String? }
            switch (try? JSONDecoder().decode(Payload.self, from: data))?.error {
            case "confirm_mismatch": throw AccountDeletionError.confirmMismatch
            case "subscription_active": throw AccountDeletionError.subscriptionActive
            default: throw AccountDeletionError.failed
            }
        }
    }
}
