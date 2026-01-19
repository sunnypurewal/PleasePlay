import SwiftUI

struct AlreadyPlayedView: View {
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
                    VStack(alignment: .leading) {
                        Text(song.title).font(.body)
                        Text(song.artist).font(.caption).foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    AlreadyPlayedView(songs: [
        Track(id: UUID(), title: "Shake It Off", artist: "Taylor Swift", album: "1989", artworkURL: nil, duration: 200),
        Track(id: UUID(), title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", artworkURL: nil, duration: 200)
    ])
}
