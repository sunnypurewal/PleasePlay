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
                    Button(action: {
                        Task {
                            _ = try? await musicPlayer.play(id: StreamingServiceIDs(song.serviceIDs))
                            await MainActor.run {
                                song.playCount += 1
                                song.playHistory.append(Date())
                                song.lastPlayedAt = Date()
                            }
                        }
                    }) {
                        HStack {
                            if let url = song.artworkURL {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(4)
                                .clipped()
                            } else {
                                Image(systemName: "music.note")
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                HStack {
                                    Text(song.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(song.playCount) plays")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    HistoryView(songs: [
        PlayedTrack(title: "Shake It Off", artist: "Taylor Swift", album: "1989", artworkURL: nil, duration: 200, serviceIDs: [:]),
        PlayedTrack(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", artworkURL: nil, duration: 200, serviceIDs: [:])
    ])
    .environment(MusicPlayer())
}
