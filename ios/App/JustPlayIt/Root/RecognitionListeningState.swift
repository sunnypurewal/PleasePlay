import Foundation
import SwiftUI
import Combine

@MainActor
final class RecognitionListeningState: ObservableObject {
    @Published var isMusicRecognitionActive = false
}
