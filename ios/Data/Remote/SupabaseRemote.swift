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

    func fetchIDs(table: SyncTable) async throws -> Data {
        try await client.from(table.rawValue).select("id").limit(10_000).execute().data
    }

    func reactivateAccount(userID: UUID) async throws {
        try await client.from("profiles")
            .update(["disabled_at": AnyJSON.null])
            .eq("id", value: userID.uuidString)
            .execute()
    }
}
