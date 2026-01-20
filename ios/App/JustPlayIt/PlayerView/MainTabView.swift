import SwiftUI
import SwiftData
import MusicStreaming

struct MainTabView: View {
    @Query private var alreadyPlayedSongs: [Track]
    
    var body: some View {
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
    }
}

#Preview {
    MainTabView()
}
