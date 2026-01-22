import SwiftUI
import MusicStreaming

struct HistoryView: View {
    @Environment(MusicPlayer.self) var musicPlayer
    @Environment(\.modelContext) private var modelContext
    let songs: [PlayedTrack]

    var body: some View {
        VStack(alignment: .leading) {
            if songs.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Songs you play will appear here.")
                }
                .frame(height: 150)
            } else {
                List(songs) { song in
                    HistoryRow(song: song)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct HistoryRow: View {
    @Environment(MusicPlayer.self) private var musicPlayer
    let song: PlayedTrack
    @State private var heartPulse = false
    @State private var isRowPressed = false
    @State private var skipNextRowTap = false

    private var isCurrentSong: Bool {
		(musicPlayer.isPlaying || musicPlayer.isSeeking) && (musicPlayer.currentTrack?.serviceIDs.contains(song) ?? false)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            artworkView

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .center, spacing: 16) {
                likeColumn

                VStack(alignment: .trailing, spacing: 2) {
                    if isCurrentSong {
                        Image(systemName: "speaker.wave.3.fill")
							.foregroundStyle(Color.accentColor)
                            .font(.caption2)
                    }
                    if song.recognizedByShazam {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tertiary)
                    }
                    Text("\(song.playCount) plays")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isRowPressed ? 0.98 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isRowPressed)
        .onTapGesture {
            guard !skipNextRowTap else {
                skipNextRowTap = false
                return
            }
            isRowPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isRowPressed = false
            }
            playSong()
        }
    }

    private var artworkView: some View {
        Group {
            if let url = song.artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray
                }
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .frame(width: 50, height: 50)
        .cornerRadius(4)
        .clipped()
    }

    private var likeColumn: some View {
        VStack(spacing: 0) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .frame(width: 58, height: 58)
                .foregroundStyle(song.likeCount > 0 ? .pink : .primary)
                .scaleEffect(heartPulse ? 1.3 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: heartPulse)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            skipNextRowTap = true
                            likeSong()
                            DispatchQueue.main.async {
                                skipNextRowTap = false
                            }
                        }
                )
            Text(song.likeCount > 0 ? "\(song.likeCount)" : " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 14)
                .opacity(song.likeCount > 0 ? 1 : 0)
        }
    }

    private func likeSong() {
        withAnimation {
            song.likeCount += 1
            heartPulse = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                heartPulse = false
            }
        }
    }

    private func playSong() {
        Task {
            _ = try? await musicPlayer.play(id: StreamingServiceIDs(playedTrack: song))
            await MainActor.run {
                song.playCount += 1
                song.playHistory.append(Date())
                song.lastPlayedAt = Date()
            }
        }
    }
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(songs: [
            PlayedTrack(title: "Shake It Off", artist: "Taylor Swift", album: "1989", artworkURL: nil, duration: 200),
            PlayedTrack(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", artworkURL: nil, duration: 200)
        ])
        .environment(MusicPlayer())
    }
}
#endif
