import SwiftUI
import MusicStreaming

struct MiniPlayerView: View {
	let currentSong: Track
	@Bindable var musicPlayer: MusicPlayer
	var isAccessory: Bool = false
	@EnvironmentObject var authManager: AuthorizationManager
	@State private var showAuthenticationSheet = false
	
	private func formatTime(_ time: TimeInterval) -> String {
		let minutes = Int(max(0, time)) / 60
		let seconds = Int(max(0, time)) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
	
	var body: some View {
		let contentBody = miniPlayerContent
			.padding(12)
			.frame(maxWidth: .infinity)
			.frame(maxHeight: .infinity, alignment: .center)

		Group {
			if isAccessory {
				contentBody
			} else {
				contentBody
					.background {
						Capsule()
							.fill(.ultraThinMaterial)
							.overlay(
								Capsule()
									.stroke(Color.white.opacity(0.3), lineWidth: 0.4)
							)
							.overlay(
								Capsule()
									.fill(
										LinearGradient(
											colors: [
												Color.white.opacity(0.35),
												Color.white.opacity(0.05),
												Color.blue.opacity(0.15)
											],
											startPoint: .topLeading,
											endPoint: .bottomTrailing
										)
									)
									.blendMode(.screen)
									.opacity(0.6)
							)
					}
					.shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
					.padding(.horizontal, 18)
			}
		}
		.sheet(isPresented: $showAuthenticationSheet) {
			AuthenticationView()
				.environmentObject(authManager)
		}
	}

	private var miniPlayerContent: some View {
		VStack(alignment: .leading, spacing: 6) {

			HStack(alignment: .center, spacing: 12) {
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
							.font(.callout)
							.lineLimit(1)

						Text(currentSong.artist)
							.font(.caption)
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
						.frame(width: 44, height: 44)
				}
				.buttonStyle(.plain)
				.foregroundColor(.primary)
			}
			.padding(.horizontal, 8)

			ProgressView(value: currentSong.duration > 0 ? musicPlayer.currentPlaybackTime : 0, total: currentSong.duration)
				.progressViewStyle(.linear)
				.tint(Color.accentColor.opacity(0.9))
				.frame(height: 2)
				.padding(.horizontal, 8)
				.opacity(currentSong.duration == 0 ? 0 : 1)
		}
	}
}

//#Preview {
//	MiniPlayerView(currentSong: Track(title: "Blackbird", artist: "The Beatles", album: "The Beatles", duration: 400), musicPlayer: .init())
//		.environmentObject(AuthorizationManager())
//}
