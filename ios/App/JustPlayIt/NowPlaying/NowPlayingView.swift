import SwiftUI
import MusicStreaming

struct NowPlayingView: View {
	let currentSong: Track
    @Bindable var musicPlayer: MusicPlayer
    
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    @State private var wasPlayingBeforeSeek = false
    @State private var showPauseDuringSeek = false
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(max(0, time)) / 60
        let seconds = Int(max(0, time)) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
	
	var body: some View {
		VStack(spacing: 20) {
			Text("Now Playing")
				.font(.headline)
				.foregroundColor(.secondary)
			
			// Album Art
            if let artworkURL = currentSong.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 200, height: 200)
                .cornerRadius(12)
                .shadow(radius: 5)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
			
			VStack(spacing: 8) {
                Text(currentSong.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(currentSong.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Seek Bar
            VStack(spacing: 5) {
                Slider(value: Binding(
                    get: { isDragging ? dragValue : musicPlayer.currentPlaybackTime },
                    set: { newValue in
                        dragValue = newValue
                    }
                ), in: 0...currentSong.duration, onEditingChanged: { editing in
                    isDragging = editing
                    if editing {
                        wasPlayingBeforeSeek = musicPlayer.isPlaying
                        showPauseDuringSeek = musicPlayer.isPlaying
                        if musicPlayer.isPlaying {
                            musicPlayer.pause()
                        }
                        dragValue = musicPlayer.currentPlaybackTime
                    } else {
                        let shouldResume = wasPlayingBeforeSeek
                        wasPlayingBeforeSeek = false
                        musicPlayer.seek(to: dragValue)
                        if shouldResume {
                            Task {
                                try? await musicPlayer.unpause()
                                showPauseDuringSeek = false
                            }
                        } else {
                            showPauseDuringSeek = false
                        }
                    }
                })
                .accentColor(.primary)
                
                HStack {
                    Text(formatTime(isDragging ? dragValue : musicPlayer.currentPlaybackTime))
                    Spacer()
                    Text("-\(formatTime(currentSong.duration - (isDragging ? dragValue : musicPlayer.currentPlaybackTime)))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
			
            HStack(spacing: 40) {
                // Stop Button
				Button(action: { 
                    musicPlayer.stop()
                }) {
					Image(systemName: "stop.fill")
						.font(.title)
				}
				
                // Play/Pause Button
				Button(action: {
					if musicPlayer.isPlaying {
						musicPlayer.pause()
					} else {
						Task {
							try? await musicPlayer.unpause()
						}
					}
                }) {
					Image(systemName: (isDragging && showPauseDuringSeek) || musicPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
						.font(.system(size: 64))
				}
			}
			.foregroundColor(.primary)
		}
		.padding()
		.background(Material.regular)
		.cornerRadius(20, corners: [.topLeft, .topRight])
		.shadow(radius: 5)
        .onChange(of: currentSong.serviceIDs) { _, _ in
            isDragging = false
            dragValue = 0
        }
	}
}

#Preview {
	NowPlayingView(
        currentSong: Track(title: "Preview Song", artist: "Preview Artist", album: "Preview Album", artworkURL: nil, duration: 180),
        musicPlayer: MusicPlayer()
    )
}
