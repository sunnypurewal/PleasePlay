import SwiftUI
import MusicStreaming

struct MiniPlayerView: View {
	let currentSong: Track
	@Bindable var musicPlayer: MusicPlayer
	@EnvironmentObject var authManager: AuthorizationManager
	@State private var showAuthenticationSheet = false
	
	private func formatTime(_ time: TimeInterval) -> String {
		let minutes = Int(max(0, time)) / 60
		let seconds = Int(max(0, time)) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
	
	var body: some View {
		VStack(spacing: 8) {
			if !authManager.isAuthorized {
				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text("Preview Only")
							.font(.caption)
							.fontWeight(.semibold)
							.textCase(.uppercase)
						Text("Connect your favourite streaming music provider to listen to full songs.")
							.font(.caption2)
							.foregroundColor(.secondary)
							.lineLimit(2)
							.multilineTextAlignment(.leading)
							.fixedSize(horizontal: false, vertical: true)
							.layoutPriority(1)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					
					Spacer()
					
					Button("Connect") {
						showAuthenticationSheet = true
					}
					.font(.caption2)
					.padding(.horizontal, 10)
					.padding(.vertical, 6)
					.background(Capsule().fill(Color.accentColor))
					.foregroundColor(.white)
				}
				.padding(12)
			}
			HStack {
				if let artworkURL = currentSong.artworkURL {
					AsyncImage(url: artworkURL) { image in
						image.resizable()
					} placeholder: {
						Rectangle().fill(Color.gray.opacity(0.3))
					}
					.frame(width: 36, height: 36)
					.cornerRadius(4)
				} else {
					Rectangle()
						.fill(Color.gray.opacity(0.3))
						.frame(width: 36, height: 36)
						.cornerRadius(4)
						.overlay(
							Image(systemName: "music.note")
								.foregroundColor(.gray)
						)
				}
				
				VStack(alignment: .leading, spacing: 2) {
					Text(currentSong.title)
						.fontWeight(.semibold)
						.lineLimit(1)
					
					Text(currentSong.artist)
						.font(.subheadline)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
				
				Spacer()
				
				Button(action: {
					if musicPlayer.isPlaying {
						musicPlayer.pause()
					} else {
						Task {
							do {
								try await musicPlayer.unpause()
							} catch {
								print("Failed to unpause from mini player: \(error)")
							}
						}
					}
				}) {
					Image(systemName: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
						.font(.title2)
				}
				.padding(.trailing)
			}
			.padding(.horizontal, 8)
			
			ProgressView(value: currentSong.duration > 0 ? musicPlayer.currentPlaybackTime : 0, total: currentSong.duration)
				.progressViewStyle(.linear)
				.accentColor(.primary)
				.padding(.horizontal, 8)
			
		}
		.padding(.vertical, 0)
		.background(.thinMaterial)
		.cornerRadius(8)
		.sheet(isPresented: $showAuthenticationSheet) {
			AuthenticationView()
				.environmentObject(authManager)
		}
	}
}

//#Preview {
//	MiniPlayerView(currentSong: Track(title: "Blackbird", artist: "The Beatles", album: "The Beatles", duration: 400), musicPlayer: .init())
//		.environmentObject(AuthorizationManager(musicPlayer: <#T##MusicPlayer#>))
//}
