//
//  JustPlayItApp.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import SwiftData

@main
struct JustPlayItApp: App {
	@StateObject private var authManager = AuthorizationManager()
	
	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
		])
		let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
		
		do {
			return try ModelContainer(for: schema, configurations: [modelConfiguration])
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}()
	
	var body: some Scene {
		WindowGroup {
			if authManager.isAuthorized {
				PlayerView()
			} else {
				AuthenticationView()
					.environmentObject(authManager)
			}
		}
		.modelContainer(sharedModelContainer)
	}
}
