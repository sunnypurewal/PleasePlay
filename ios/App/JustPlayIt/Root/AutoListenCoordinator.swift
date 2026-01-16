import Foundation
import MusicStreaming
import MusicAI
import UIKit
import Combine
import AVFoundation

@MainActor
final class AutoListenCoordinator: ObservableObject {
	private var musicPlayer: MusicStreaming.MusicPlayer
    private var recognitionState: RecognitionListeningState
    
    private var cancellables = Set<AnyCancellable>()
    
	init(musicPlayer: MusicStreaming.MusicPlayer, recognitionState: RecognitionListeningState) {
        self.musicPlayer = musicPlayer
        self.recognitionState = recognitionState
        
        setupObservations()
    }
    
    private func setupObservations() {
        musicPlayer.onIsPlayingChange = { [weak self] isPlaying in
            Task { @MainActor in
                self?.handlePlaybackStateChange(isPlaying: isPlaying)
            }
        }
        
        recognitionState.$isMusicRecognitionActive
            .dropFirst()
            .sink { [weak self] isActive in
                Task { @MainActor in
                    if isActive {
                        await self?.recognitionState.stopMicrophoneStreaming()
                    } else {
                        await self?.startListeningIfAllowed()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func handlePlaybackStateChange(isPlaying: Bool) {
        Task {
            if isPlaying {
                await recognitionState.stopMicrophoneStreaming()
            } else {
                await startListeningIfAllowed()
            }
        }
    }
    
    private func startListeningIfAllowed() async {
        guard UserDefaults.standard.bool(forKey: "isAutomaticListeningEnabled"),
              recognitionState.shouldAutomaticallyListenForCommands,
              !recognitionState.isMusicRecognitionActive,
              !musicPlayer.isPlaying,
              !recognitionState.isMicrophoneStreaming else { return }
        
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "StartAutoListen") {
            // End task if it takes too long
        }
        
        do {
            try await recognitionState.startMicrophoneStreaming()
            print("AutoListenCoordinator: Started listening in background")
        } catch {
            print("AutoListenCoordinator: Failed to start listening: \(error)")
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
}
