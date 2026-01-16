//
//  PlayerView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import AVFoundation

struct PlayerView: View {
	@StateObject private var speechRecognizer = SpeechRecognizer()
	@State private var microphonePermissionGranted = false
	@State private var alreadyPlayedSongs: [String] = [] // Mock data for now
	@State private var nowPlayingSong: String? = nil
	
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
					PlayerEmptyStateView(transcript: speechRecognizer.transcript)
				}
			}
			.navigationTitle("Player")
			.onAppear {
				checkMicrophonePermission()
			}
			.onChange(of: microphonePermissionGranted) { _, newValue in
				if newValue {
					speechRecognizer.startTranscribing()
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
			speechRecognizer.startTranscribing()
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
