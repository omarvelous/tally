//
//  SupabaseManager.swift
//  Tally
//
//  Singleton Supabase client used by the auth and sync layers.
//  Uses the anon (publishable) key — RLS policies enforce data isolation.

import Foundation
import Supabase

enum SupabaseManager {
    static let projectRef = "jcgfxygnfsirgdrmcwjb"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjZ2Z4eWduZnNpcmdkcm1jd2piIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MDgyNzgsImV4cCI6MjA5NTA4NDI3OH0.pscg-6rk7HVhp2JPtF4UTGU7lpEO1QkOHnx-nNpyzAU"

    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://\(projectRef).supabase.co")!,
        supabaseKey: anonKey
    )
}
