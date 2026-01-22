//
//  PlayerView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import AVFoundation
import CoreML
import SwiftData
import Tokenizers
import MusicStreaming
import MusicAI

struct PlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MusicPlayer.self) var musicPlayer
    @EnvironmentObject private var recognitionState: RecognitionListeningState
	@State private var microphonePermissionGranted = false
    @AppStorage("isAutomaticListeningEnabled") private var isAutomaticListeningEnabled = true
	@State var recorder: Recorder
	@State var speechTranscriber: SpokenWordTranscriber
	@State var predictor: Predictor
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
	@State private var hasAppeared = false

	init() {
		let transcriber = SpokenWordTranscriber()
		recorder = Recorder(transcriber: transcriber)
		speechTranscriber = transcriber
		predictor = Predictor()
	}
	
	var body: some View {
		VStack {
			// Microphone Permission Banner
			if !microphonePermissionGranted {
				MicrophonePermissionView(onRequestAccess: requestMicrophoneAccess)
			}
			
            if !musicPlayer.isPlaying && (musicPlayer.isUserPaused || musicPlayer.currentTrack == nil) {
                MicrophoneStatusView(recorder: recorder, isAutomaticListeningEnabled: $isAutomaticListeningEnabled)
            }
			
			Spacer()
			
			// Content for Empty State vs Now Playing
			if isSearching {
				ProgressView("Searching...")
				Spacer()
			} else if !searchResults.isEmpty {
				VStack(alignment: .leading) {
					Text("Search Results")
						.font(.headline)
						.padding(.horizontal)
					
					List(searchResults, id: \.serviceIDs) { track in
						Button(action: {
							Task {
								await cancelRecognitionBeforePlayback()
								try? await musicPlayer.play(id: track.serviceIDs)
								await MainActor.run {
									saveTrack(track)
								}
							}
						}) {
							HStack {
								if let url = track.artworkURL {
									AsyncImage(url: url) { image in
										image.resizable()
									} placeholder: {
										Color.gray
									}
									.frame(width: 50, height: 50)
									.cornerRadius(4)
								} else {
									Image(systemName: "music.note")
										.frame(width: 50, height: 50)
										.background(Color.secondary.opacity(0.1))
										.cornerRadius(4)
								}
								
								VStack(alignment: .leading) {
									Text(track.title)
										.font(.headline)
									Text(track.artist)
										.font(.subheadline)
									.foregroundColor(.secondary)
								}
								
								Spacer()
								
								if musicPlayer.currentTrack?.serviceIDs == track.serviceIDs {
									Image(systemName: "speaker.wave.3.fill")
										.foregroundColor(.accentColor)
										.font(.caption)
								}
							}
						}
					}
					.listStyle(.plain)
				}
			} else {
				PlayerEmptyStateView(recorder: recorder, transcript: speechTranscriber.finalizedTranscript, isRecording: recorder.isRecording)
			}
		}
		.onAppear {
			checkMicrophonePermission(shouldStartListening: !hasAppeared)
			hasAppeared = true
		}
		.onChange(of: speechTranscriber.finalizedTranscript) { old, new in
			let text = String(new.characters)
			if !text.isEmpty {
				Task {
					do {
						let output = try await predictor.predictEntities(from: text)
						
						speechTranscriber.resetTranscripts()
						print(output)
						
						let artists = output["Artists"] as? [String] ?? []
						let woas = output["WoAs"] as? [String] ?? []
						
						let artist = artists.first ?? ""
						let title = woas.first ?? ""
						
						let query = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
						let searchQuery = query.isEmpty ? text : query
						
						if !searchQuery.isEmpty {
							isSearching = true
							// Perform search
							async let searchTask = musicPlayer.search(query: searchQuery)
							
							var playedTrack: Track?
							if !artist.isEmpty || !title.isEmpty {
								await cancelRecognitionBeforePlayback()
								playedTrack = try? await musicPlayer.play(artist: artist, song: title)
							}
							
							let results = try? await searchTask
							
							await MainActor.run {
								if let track = playedTrack {
									saveTrack(track)
								}
								let allResults = results ?? []
								if title.isEmpty && !artist.isEmpty {
									self.searchResults = allResults
								} else {
									self.searchResults = allResults.filter { track in
										allResults.contains { $0.title.lowercased() == track.title.lowercased() && $0.artist.lowercased() != track.artist.lowercased() }
									}
								}
								self.isSearching = false
							}
						}
					} catch {
						print("Prediction error: \(error)")
						isSearching = false
					}
				}
			}
		}
		.onChange(of: musicPlayer.isPlaying) { _, isPlaying in
			if isPlaying {
				recorder.pauseRecording()
			} else if isAutomaticListeningEnabled && !recognitionState.isMusicRecognitionActive {
                Task { try? await recorder.record() }
			}
		}
        .onChange(of: recognitionState.isMusicRecognitionActive) { _, isActive in
            Task {
                if isActive {
                    recorder.pauseRecording()
                } else if isAutomaticListeningEnabled && !musicPlayer.isPlaying && microphonePermissionGranted {
                    try? await recorder.record()
                }
            }
        }
		.task {
			do {
				try await predictor.loadModel()
			} catch {
				print("Failed to load model: \(error)")
			}
		}
	}
	
	private func checkMicrophonePermission(shouldStartListening: Bool) {
		let isGranted: Bool
		if #available(iOS 17.0, *) {
			switch AVAudioApplication.shared.recordPermission {
				case .granted:
					isGranted = true
				case .denied, .undetermined:
					isGranted = false
				@unknown default:
					isGranted = false
			}
		} else {
			switch AVAudioSession.sharedInstance().recordPermission {
				case .granted:
					isGranted = true
				case .denied, .undetermined:
					isGranted = false
				@unknown default:
					isGranted = false
			}
		}
		
		microphonePermissionGranted = isGranted
		if shouldStartListening && isGranted && !musicPlayer.isPlaying && isAutomaticListeningEnabled && !recognitionState.isMusicRecognitionActive {
			Task { 
                try await recorder.record()
            }
		}
	}
	
	private func requestMicrophoneAccess() {
		if #available(iOS 17.0, *) {
			AVAudioApplication.requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
					if granted && self.isAutomaticListeningEnabled && !recognitionState.isMusicRecognitionActive {
						Task { 
                            try? await self.recorder.record() 
                        }
					}
				}
			}
		} else {
			AVAudioSession.sharedInstance().requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
					if granted && self.isAutomaticListeningEnabled && !recognitionState.isMusicRecognitionActive {
						Task { 
                            try? await self.recorder.record() 
                        }
					}
				}
			}
		}
	}

	private func cancelRecognitionBeforePlayback() async {
		guard recognitionState.isMusicRecognitionActive else { return }
		await recognitionState.requestCancelRecognition(skipResume: true)
	}
    
	private func saveTrack(_ track: Track) {
        let title = track.title
        let artist = track.artist
        
        let descriptor = FetchDescriptor<PlayedTrack>(
            predicate: #Predicate { $0.title == title && $0.artist == artist }
        )
        
        do {
            let existingTracks = try modelContext.fetch(descriptor)
            if let existingTrack = existingTracks.first {
                existingTrack.playCount += 1
                existingTrack.playHistory.append(Date())
                existingTrack.lastPlayedAt = Date()
            } else {
                let playedTrack = PlayedTrack(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    artworkURL: track.artworkURL,
                    duration: track.duration,
                    appleMusicID: track.serviceIDs.appleMusic,
                    spotifyID: track.serviceIDs.spotify,
                    tidalID: track.serviceIDs.tidal,
                    youTubeID: track.serviceIDs.youtube
                )
                modelContext.insert(playedTrack)
            }
        } catch {
            print("Failed to save track: \(error)")
        }
    }
}

#Preview {
	PlayerView()
        .environment(MusicPlayer())
        .environmentObject(RecognitionListeningState())
}
