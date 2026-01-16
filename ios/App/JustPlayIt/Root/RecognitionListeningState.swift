import Foundation
import SwiftUI
import Combine
import MusicAI

@MainActor
final class RecognitionListeningState: ObservableObject {
    @Published var isMusicRecognitionActive = false
    @Published private(set) var shouldAutomaticallyListenForCommands = true
    var cancelRecognition: (() async -> Void)?
    var shouldResumePlaybackAfterRecognition = true

    let microphoneInput = MicrophoneInput()
    let speechTranscriber = SpokenWordTranscriber()
    @Published var isMicrophoneStreaming = false

    func requestCancelRecognition(skipResume: Bool = false) async {
        if skipResume {
            shouldResumePlaybackAfterRecognition = false
        }

        guard let cancelRecognition else {
            return
        }

        await cancelRecognition()
    }

    func clearCancelRecognitionHandler() {
        cancelRecognition = nil
    }

    func disableAutomaticCommandListening() {
        shouldAutomaticallyListenForCommands = false
    }

    func enableAutomaticCommandListening() {
        shouldAutomaticallyListenForCommands = true
    }

    func startMicrophoneStreaming() async throws {
        guard !isMicrophoneStreaming else { return }
        do {
            try await speechTranscriber.setUpTranscriber()
            let stream = try await microphoneInput.startStreaming()
            speechTranscriber.startTranscribing(from: stream)
            isMicrophoneStreaming = true
        } catch {
            await microphoneInput.stopStreaming()
            throw error
        }
    }

    func stopMicrophoneStreaming() async {
        guard isMicrophoneStreaming else { return }
        await microphoneInput.stopStreaming()
        do {
            try await speechTranscriber.finishTranscribing()
        } catch {
            print("Failed to finish transcribing: \(error)")
        }
        isMicrophoneStreaming = false
    }
}
