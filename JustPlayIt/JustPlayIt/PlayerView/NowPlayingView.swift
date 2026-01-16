import SwiftUI
import UIKit

struct NowPlayingView: View {
	let currentSong: String
	
	var body: some View {
		VStack(spacing: 20) {
			Text("Now Playing")
				.font(.headline)
				.foregroundColor(.secondary)
			
			// Album Art Placeholder
			Rectangle()
				.fill(Color.gray.opacity(0.3))
				.frame(width: 200, height: 200)
				.cornerRadius(12)
				.overlay(
					Image(systemName: "music.note")
						.font(.largeTitle)
						.foregroundColor(.gray)
				)
			
			Text(currentSong)
				.font(.title3)
				.fontWeight(.bold)
			
			HStack(spacing: 40) {
				Button(action: { /* prev */ }) {
					Image(systemName: "backward.fill")
						.font(.title)
				}
				
				Button(action: { /* play/pause */ }) {
					Image(systemName: "pause.circle.fill")
						.font(.system(size: 64))
				}
				
				Button(action: { /* next */ }) {
					Image(systemName: "forward.fill")
						.font(.title)
				}
			}
			.foregroundColor(.primary)
		}
		.padding()
		.background(Material.regular)
		.cornerRadius(20, corners: [.topLeft, .topRight])
		.shadow(radius: 5)
	}
}

#Preview {
	NowPlayingView(currentSong: "Preview Song")
}
