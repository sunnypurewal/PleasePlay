import SwiftUI

struct PlayerEmptyStateView: View {
	var recorder: AudioRecording
	var transcript: AttributedString = ""
	var isRecording: Bool = false
	
	var body: some View {
		VStack(spacing: 16) {
			if !transcript.characters.isEmpty {
				Text(transcript)
					.font(.title3)
					.multilineTextAlignment(.center)
					.padding()
					.transition(.opacity)
			}
			
			Button(action: { Task { try? await recorder.toggleRecording() } }) {
				Image(systemName: isRecording ? "mic.fill" : "mic.slash.fill")
					.font(.system(size: 50))
					.foregroundColor(isRecording ? .accentColor : .secondary)
					.padding(12)
					.background(Color.secondary.opacity(0.1))
					.clipShape(Circle())
			}
			
			if isRecording {
				Text("Ready to Play?")
					.font(.title2)
					.fontWeight(.bold)
				Text("Try saying:")
					.foregroundColor(.secondary)
				Text("\"Please play Blackbird by The Beatles\"")
					.font(.headline)
					.padding()
					.background(Color.secondary.opacity(0.1))
					.cornerRadius(8)
			}
		}
		.padding(.bottom, 50)
	}
}

