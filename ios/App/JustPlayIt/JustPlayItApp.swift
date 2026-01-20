//
//  JustPlayItApp.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import SwiftData
import MusicStreaming

@main
struct JustPlayItApp: App {
	@StateObject private var authManager: AuthorizationManager
    @State private var musicPlayer = MusicPlayer()
	
    init() {
        let musicPlayer = MusicPlayer()
        _musicPlayer = State(initialValue: musicPlayer)
        _authManager = StateObject(wrappedValue: AuthorizationManager(musicPlayer: musicPlayer))
    }

	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
            Track.self
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
				MainTabView()
                    .environment(musicPlayer)
			} else {
				AuthenticationView()
					.environmentObject(authManager)
			}
		}
		.modelContainer(sharedModelContainer)
	}
}