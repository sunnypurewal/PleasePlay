import Foundation
import SwiftUI
import Combine

@MainActor
final class RecognitionListeningState: ObservableObject {
    @Published var isMusicRecognitionActive = false
    var cancelRecognition: (() async -> Void)?
    var shouldResumePlaybackAfterRecognition = true

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
}
