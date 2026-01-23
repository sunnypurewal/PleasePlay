import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var historySongs: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @State private var showPlayer = false
    @State private var showAuthenticationSheet = false
    @EnvironmentObject private var authManager: AuthorizationManager
    
    private var shouldShowAuthenticationBanner: Bool {
        !authManager.isAuthorized && musicPlayer.isPlaying && musicPlayer.currentTrack != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowAuthenticationBanner {
                AuthenticationReminderBanner {
                    showAuthenticationSheet = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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
                    MiniPlayerView(currentSong: currentSong, musicPlayer: musicPlayer)
                        .contentShape(Rectangle())
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
        .sheet(isPresented: $showAuthenticationSheet) {
            AuthenticationView()
                .environmentObject(authManager)
        }
        .onChange(of: authManager.isAuthorized) { _, isAuthorized in
            if isAuthorized {
                showAuthenticationSheet = false
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
private struct AuthenticationReminderBanner: View {
    let connectAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: "music.note.list")
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preview mode")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                Text("Connect your favourite streaming music provider to listen to full songs.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Connect") {
                connectAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .shadow(radius: 4, y: 2)
    }
}
