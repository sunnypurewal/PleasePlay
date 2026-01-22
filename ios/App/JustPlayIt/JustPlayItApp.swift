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
	@StateObject private var recognitionState = RecognitionListeningState()
	
	init() {
		let musicPlayer = MusicPlayer()
		_musicPlayer = State(initialValue: musicPlayer)
		_authManager = StateObject(wrappedValue: AuthorizationManager(musicPlayer: musicPlayer))
	}

	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
            PlayedTrack.self
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
			Group {
				if authManager.isLoading {
					ProgressView()
				} else {
					MainTabView()
				}
			}
			.environment(musicPlayer)
			.environmentObject(recognitionState)
			.environmentObject(authManager)
			.task {
				configureRecognitionPrePlayHook()
			}
		}
		.modelContainer(sharedModelContainer)
	}

	@MainActor
	private func configureRecognitionPrePlayHook() {
		musicPlayer.prePlayHook = {
			await recognitionState.requestCancelRecognition(skipResume: true)
		}
	}
}
