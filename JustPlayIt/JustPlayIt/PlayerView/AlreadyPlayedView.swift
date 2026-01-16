import SwiftUI

struct AlreadyPlayedView: View {
    let songs: [String]
    
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
                List(songs, id: \.self) { song in
                    Text(song)
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    AlreadyPlayedView(songs: ["Song 1", "Song 2"])
}
