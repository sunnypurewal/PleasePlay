import Foundation
@preconcurrency import Auth
@preconcurrency import Player
@preconcurrency import TidalAPI
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
    public let name: String = "Tidal"
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
    private func setup(clientId: String, clientSecret: String) {
        let config = AuthConfig(clientId: clientId, clientSecret: clientSecret, credentialsKey: "tidal_credentials")
        TidalAuth.shared.config(config: config)
        
        let credentialsProvider = TidalAuth.shared
        let eventSender = TidalEventSender()
        
        self.player = Player.bootstrap(playerListener: self.listener!, credentialsProvider: credentialsProvider, eventSender: eventSender)
		OpenAPIClientAPI.credentialsProvider = credentialsProvider
    }

    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
		do {
			let searchTerm = "\(song) \(artist)"
			let results = try await SearchResultsAPITidal.searchResultsIdGet(id: searchTerm, explicitFilter: .include, include: ["tracks"])
			let trackID = results.data.id
			let track = try await TracksAPITidal.tracksIdGet(id: trackID)
			let mediaProduct = MediaProduct(productType: .TRACK, productId: trackID)
			player?.load(mediaProduct)
			player?.play()
			
			let newTrack = Track(
				title: song,
				artist: artist,
				album: "",
				artworkURL: nil,
				duration: 120,
				serviceIDs: .init(tidal: trackID)
			)
			
			self.currentTrack = newTrack
			isPlaying = true
			return newTrack
		} catch {
			if let error = error as? HTTPErrorResponse, let data = error.data {
				let str = String(data: data, encoding: .utf8)
				print(str)
			}
			throw error
		}
    }
    
    @discardableResult
    public func play(track: Track) async throws -> Track {
        guard let player = player else { throw TidalError.playerNotInitialized }
        if let trackID = track.serviceIDs.tidal {
            let mediaProduct = MediaProduct(productType: .TRACK, productId: trackID)
            player.load(mediaProduct)
            player.play()
            currentTrack = track
            isPlaying = true
            return track
        }
        return try await play(artist: track.artist, song: track.title)
    }

    public func search(query: String) async throws -> [Track] {
        // Skipping implementation for now
        return []
    }

    public func getTopSongs(for artist: String) async throws -> [Track] {
        return []
    }

    public func getAlbums(for artist: String) async throws -> [Album] {
        return []
    }
	    
	        
	    
	        public func pause() {        player?.pause()
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
