import Foundation
@preconcurrency import Auth
@preconcurrency import Player
@_exported import TidalAPI
@preconcurrency import EventProducer
import Observation

private class TidalPlayerListener: PlayerListener {
    weak var tidal: Tidal?
    
    init(tidal: Tidal) {
        self.tidal = tidal
    }
    
    func stateChanged(to state: State) {
        let tidal = self.tidal
        Task { @MainActor in
            tidal?.isPlaying = state == .PLAYING
        }
    }
    func ended(_ mediaProduct: MediaProduct) {}
    func mediaTransitioned(to mediaProduct: MediaProduct, with playbackContext: PlaybackContext) {}
    func failed(with error: PlayerError) {}
    func mediaServicesWereReset() {}
}

@MainActor
@Observable
public class Tidal: StreamingMusicProvider {
    public var isPlaying: Bool = false
    public var currentTrack: Track?
    public var currentPlaybackTime: TimeInterval = 0
    
    private var player: Player?
    private var listener: TidalPlayerListener?

    public init(clientId: String, clientSecret: String) {
        self.listener = TidalPlayerListener(tidal: self)
        Task {
            await setup(clientId: clientId, clientSecret: clientSecret)
        }
    }
    
    @MainActor
    private func setup(clientId: String, clientSecret: String) async {
        let config = AuthConfig(clientId: clientId, clientSecret: clientSecret, credentialsKey: "tidal_credentials")
        TidalAuth.shared.config(config: config)
        
        let credentialsProvider = TidalAuth.shared
        let eventSender = TidalEventSender()
        
        self.player = Player.bootstrap(playerListener: self.listener!, credentialsProvider: credentialsProvider, eventSender: eventSender)
        
        // OpenAPIClientAPI.credentialsProvider = credentialsProvider
    }

    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
        // let response = try await SearchResultsAPI.search(query: "\(artist) \(song)", limit: 1)
        
        // guard let item = response.data?.items?.first,
        //       let trackResource = item.item?.asTracksResourceObject,
        //       let trackId = trackResource.id else {
        //     throw TidalError.songNotFound
        // }

        // let tidalTrack = try await TracksAPI.getTrack(trackId: trackId)
        
        // let track = Track(
        //     title: tidalTrack.data?.title ?? "",
        //     artist: tidalTrack.data?.artists?.first?.name ?? "",
        //     album: tidalTrack.data?.album?.title ?? "",
        //     artworkURL: URL(string: tidalTrack.data?.album?.imageCover ?? ""),
        //     duration: tidalTrack.data?.duration ?? 0,
        //     serviceIDs: .init(tidal: tidalTrack.data?.id)
        // )
        
        // try await play(trackID: trackId)
        // self.currentTrack = track
        // return track
        throw TidalError.notImplemented
    }
    
	public func play(id: StreamingServiceIDs) async throws {
        guard let player = player else { throw TidalError.playerNotInitialized }
		guard let trackID = id.tidal else { throw TidalError.songNotFound }
        
        let mediaProduct = MediaProduct(productType: .TRACK, productId: trackID)
        player.load(mediaProduct)
        player.play()
    }
    
    public func pause() {
        player?.pause()
    }
    
    public func unpause() async throws {
        player?.play()
    }
    
    public func stop() {
        player?.pause()
        player?.seek(0)
    }
    
    public func seek(to time: TimeInterval) {
        player?.seek(time)
    }
}

public enum TidalError: Error {
    case notImplemented
    case playerNotInitialized
    case songNotFound
}
