//
//  PlayerView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import AVFoundation
import CoreML
import Tokenizers

struct PlayerView: View {
	@State private var microphonePermissionGranted = false
	@State private var alreadyPlayedSongs: [String] = [] // Mock data for now
	@State private var nowPlayingSong: String? = nil
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
				
				// Already Played Section
				AlreadyPlayedView(songs: alreadyPlayedSongs)
				
				Spacer()
				
				// Content for Empty State vs Now Playing
				if let currentSong = nowPlayingSong {
					NowPlayingView(currentSong: currentSong)
				} else {
					PlayerEmptyStateView(transcript: speechTranscriber.finalizedTranscript)
				}
			}
			.navigationTitle("Player")
			.onAppear {
				checkMicrophonePermission()
			}
			.onChange(of: speechTranscriber.finalizedTranscript) { old, new in
				let text = String(new.characters)
				if !text.isEmpty {
					Task {
						do {
							let output = try await predictor.predictEntities(from: text)
							print(output)
						} catch {
							print("Prediction error: \(error)")
						}
					}
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
		if isGranted {
			Task { try await recorder.record() }
		}
	}
	
	private func requestMicrophoneAccess() {
		if #available(iOS 17.0, *) {
			AVAudioApplication.requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
				}
			}
		} else {
			AVAudioSession.sharedInstance().requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
				}
			}
		}
	}
}

#Preview {
	PlayerView()
}
