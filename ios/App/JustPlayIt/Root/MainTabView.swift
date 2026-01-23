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
                        .padding(.bottom, bottomPadding(for: safeAreaBottom))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $showPlayer) {
            if let currentSong = musicPlayer.currentTrack {
                NowPlayingView(currentSong: currentSong, musicPlayer: musicPlayer)
            }
        }
    }

    private func bottomPadding(for safeAreaBottom: CGFloat) -> CGFloat {
        let tabBarHeight: CGFloat = 49
        let basePadding = max(0, tabBarHeight - safeAreaBottom)
        let previewBannerExtra: CGFloat = authManager.isAuthorized ? 0 : 64
        return basePadding + previewBannerExtra
    }
}

#Preview {
    let previewPlayer = MusicPlayer()
    MainTabView()
        .environment(previewPlayer)
        .environmentObject(RecognitionListeningState())
        .environmentObject(AuthorizationManager(musicPlayer: previewPlayer))
}
