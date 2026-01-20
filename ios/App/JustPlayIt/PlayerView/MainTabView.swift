import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query private var alreadyPlayedSongs: [Track]
    @Environment(MusicPlayer.self) var musicPlayer
    @State private var showPlayer = false
    
    var body: some View {
        ZStack {
            TabView {
                PlayerView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                NavigationStack {
                    AlreadyPlayedView(songs: alreadyPlayedSongs)
                        .navigationTitle("History")
                }
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let currentSong = musicPlayer.currentTrack {
                    MiniPlayerView(currentSong: currentSong, musicPlayer: musicPlayer)
                        .onTapGesture {
                            showPlayer = true
                        }
                }
            }
        }
        .sheet(isPresented: $showPlayer) {
            if let currentSong = musicPlayer.currentTrack {
                NowPlayingView(currentSong: currentSong, musicPlayer: musicPlayer)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(MusicPlayer())
}
