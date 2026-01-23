import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var historySongs: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @State private var showPlayer = false
    @EnvironmentObject private var authManager: AuthorizationManager

    var body: some View {
        GeometryReader { geometry in
            let safeAreaBottom = geometry.safeAreaInsets.bottom
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
						.padding(.bottom, geometry.safeAreaInsets.bottom)
						.border(.red)
                }
            }
//            .frame(width: geometry.size.width, height: geometry.size.height)
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
        .environmentObject(AuthorizationManager(musicPlayer: previewPlayer))
}
