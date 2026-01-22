import SwiftUI
import MusicStreaming

struct MiniPlayerView: View {
    let currentSong: Track
    @Bindable var musicPlayer: MusicPlayer
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(max(0, time)) / 60
        let seconds = Int(max(0, time)) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 8) {
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
                
                Text(currentSong.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    if musicPlayer.isPlaying {
                        musicPlayer.pause()
                    } else {
                        Task {
                            try? await musicPlayer.unpause()
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
        .background(.thinMaterial)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(height: 68)
    }
}
