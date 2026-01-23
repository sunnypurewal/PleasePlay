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
		_authManager = StateObject(wrappedValue: AuthorizationManager())
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
				applyCurrentProvider()
			}
			.onChange(of: authManager.currentProvider) { _, _ in
				applyCurrentProvider()
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

	@MainActor
	private func applyCurrentProvider() {
		let wasPlaying = musicPlayer.isPlaying
		guard let previouslyPlayingTrack = musicPlayer.currentTrack else {
			musicPlayer.setProvider(authManager.providerForCurrentSelection())
			return
		}
		musicPlayer.stop()
		musicPlayer.setProvider(authManager.providerForCurrentSelection())
		if wasPlaying {
			Task {
				do {
					_ = try await musicPlayer.play(track: previouslyPlayingTrack)
				} catch {
					print("Failed to restart playback after provider switch: \(error)")
				}
			}
		}
	}
}
