import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var historySongs: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @State private var showPlayer = false
    @EnvironmentObject private var authManager: AuthorizationManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            NavigationStack {
                DiscoverView()
                    .navigationTitle("Discover")
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles")
            }
            
            NavigationStack {
                HistoryView(songs: historySongs)
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
        }
        .tabViewBottomAccessory {
            if let currentSong = musicPlayer.currentTrack {
                MiniPlayerView(currentSong: currentSong, musicPlayer: musicPlayer, isAccessory: true)
                    .onTapGesture {
                        showPlayer = true
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
    let previewPlayer = MusicPlayer()
    MainTabView()
        .environment(previewPlayer)
        .environmentObject(RecognitionListeningState())
        .environmentObject(AuthorizationManager())
}
