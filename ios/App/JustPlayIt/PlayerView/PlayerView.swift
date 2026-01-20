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
	@State private var microphonePermissionGranted = false
	@State var recorder: Recorder
	@State var speechTranscriber: SpokenWordTranscriber
	@State var predictor: Predictor

	init() {
		let transcriber = SpokenWordTranscriber()
		recorder = Recorder(transcriber: transcriber)
		speechTranscriber = transcriber
		predictor = Predictor()
	}
	
	var body: some View {
		NavigationStack {
			VStack {
				// Microphone Permission Banner
				if !microphonePermissionGranted {
					MicrophonePermissionView(onRequestAccess: requestMicrophoneAccess)
				}
				
				Spacer()
				
				// Content for Empty State vs Now Playing
				PlayerEmptyStateView(transcript: speechTranscriber.finalizedTranscript)
			}
			.navigationTitle("Player")
			.onAppear {
				if !microphonePermissionGranted {
					checkMicrophonePermission()
				}
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
							
							if !artist.isEmpty || !title.isEmpty {
                                let track = try await musicPlayer.play(artist: artist, song: title)
                                
                                await MainActor.run {
                                    modelContext.insert(track)
                                }
							}
						} catch {
							print("Prediction error: \(error)")
						}
					}
				}
			}
            .onChange(of: musicPlayer.isPlaying) { _, isPlaying in
                if isPlaying {
                    recorder.pauseRecording()
                } else {
                    try? recorder.resumeRecording()
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
	}
	
	private func checkMicrophonePermission() {
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
		if isGranted && !musicPlayer.isPlaying {
			Task { try await recorder.record() }
		}
	}
	
	private func requestMicrophoneAccess() {
		if #available(iOS 17.0, *) {
			AVAudioApplication.requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
					if granted {
						Task { try? await self.recorder.record() }
					}
				}
			}
		} else {
			AVAudioSession.sharedInstance().requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
					if granted {
						Task { try? await self.recorder.record() }
					}
				}
			}
		}
	}
}

#Preview {
	PlayerView()
        .environment(MusicPlayer())
}
