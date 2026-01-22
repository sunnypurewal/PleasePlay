import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var historySongs: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @State private var showPlayer = false
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
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
                
                if let currentSong = musicPlayer.currentTrack {
                    MiniPlayerView(currentSong: currentSong, musicPlayer: musicPlayer)
                        .onTapGesture {
                            showPlayer = true
                        }
                        // Add padding to lift the mini player above the tab bar.
                        // 49pt is the standard height for a tab bar.
                        .padding(.bottom, 49)
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
        .environmentObject(RecognitionListeningState())
}
