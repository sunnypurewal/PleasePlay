import SwiftUI
import MusicStreaming

struct MiniPlayerView: View {
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
                    Image(systemName: (isDragging && showPauseDuringSeek) || musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .padding(.trailing)
            }
            .padding(8)
            
            Slider(value: Binding(
                get: { isDragging ? dragValue : musicPlayer.currentPlaybackTime },
                set: { newValue in
                    dragValue = newValue
                }
            ), in: 0...currentSong.duration, onEditingChanged: { editing in
                isDragging = editing
                if editing {
                    musicPlayer.isSeeking = true
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
                    musicPlayer.isSeeking = false
                }
            })
            .tint(.primary)
            .padding(.horizontal, 8)
            
            HStack {
                Text(formatTime(isDragging ? dragValue : musicPlayer.currentPlaybackTime))
                Spacer()
                Text("-\(formatTime(currentSong.duration - (isDragging ? dragValue : musicPlayer.currentPlaybackTime)))")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .background(.thinMaterial)
        .cornerRadius(8)
        .padding(.horizontal)
        .onChange(of: currentSong.serviceIDs) { _, _ in
            isDragging = false
            dragValue = 0
        }
    }
}
