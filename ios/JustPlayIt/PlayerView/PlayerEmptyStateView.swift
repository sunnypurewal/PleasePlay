import SwiftUI

struct PlayerEmptyStateView: View {
	var transcript: AttributedString = ""
	
	var body: some View {
		VStack(spacing: 16) {
			if !transcript.characters.isEmpty {
				Text(transcript)
					.font(.title3)
					.multilineTextAlignment(.center)
					.padding()
					.transition(.opacity)
			}
			
			Image(systemName: "mic.fill.badge.plus")
				.font(.system(size: 50))
				.foregroundColor(.accentColor)
			
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
		.padding(.bottom, 50)
	}
}

#Preview {
	PlayerEmptyStateView()
}
