import SwiftUI

struct AlreadyPlayedView: View {
    @Environment(AppleMusic.self) var musicPlayer
    let songs: [Track]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Already Played")
                .font(.headline)
                .padding(.horizontal)
            
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
                            try? await musicPlayer.play(track: song)
                        }
                    }) {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    AlreadyPlayedView(songs: [
        Track(uuid: UUID(), title: "Shake It Off", artist: "Taylor Swift", album: "1989", artworkURL: nil, duration: 200),
        Track(uuid: UUID(), title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", artworkURL: nil, duration: 200)
    ])
    .environment(AppleMusic())
}
