import SwiftUI
import MusicStreaming

struct MiniPlayerView: View {
    let currentSong: Track
    var musicPlayer: MusicPlayer
    
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let artworkURL = currentSong.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(4)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 48, height: 48)
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
            .padding(8)
            
            Slider(value: Binding(
                get: { isDragging ? dragValue : musicPlayer.currentPlaybackTime },
                set: { newValue in
                    dragValue = newValue
                    musicPlayer.seek(to: newValue)
                }
            ), in: 0...currentSong.duration, onEditingChanged: { editing in
                isDragging = editing
                if editing {
                    dragValue = musicPlayer.currentPlaybackTime
                }
            })
            .tint(.primary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .background(.thinMaterial)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
