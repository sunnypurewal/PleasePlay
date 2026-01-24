//
//  AppleMusic.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation
@_implementationOnly @preconcurrency import MusicKit
import Observation

@MainActor
@Observable
public class AppleMusic: StreamingMusicProvider {
    public let name: String = "Apple Music"
    private let player = ApplicationMusicPlayer.shared
    public var isPlaying: Bool = false
    public var currentTrack: Track?
    public var currentPlaybackTime: TimeInterval = 0
    private var playbackMonitorTask: Task<Void, Never>?

    public init() {}
    
    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
        let searchTerm = "\(song) \(artist)"
        let searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        
        let response: MusicCatalogSearchResponse
        do {
            response = try await searchRequest.response()
        } catch {
             print("""
            
            ⚠️ MusicKit Error: \(error.localizedDescription)
            ---------------------------------------------------------------
            It looks like 'com.riddimsoftware.JustPlayIt' is not registered 
            properly in the Apple Developer Portal with the 'MusicKit' service.
            
            To fix this:
            1. Go to https://developer.apple.com/account/resources/identifiers/list
            2. Find or Create the App ID: com.riddimsoftware.JustPlayIt
            3. Enable the 'MusicKit' App Service.
            4. Make sure your provisioning profile is updated.
            ---------------------------------------------------------------
            Running in MOCK MODE for now.
            Playing: \(song) by \(artist)
            
            """)
            throw AppleMusicError.songNotFound
        }
        
        guard let songItem = response.songs.first else {
            throw AppleMusicError.songNotFound
        }
        
        return try await playSongItem(songItem)
    }

    @discardableResult
    public func play(track: Track) async throws -> Track {
        if let trackID = track.serviceIDs.appleMusic {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(trackID))
            let response = try await request.response()
            guard let songItem = response.items.first else {
                throw AppleMusicError.songNotFound
            }
            return try await playSongItem(songItem)
        }
        return try await play(artist: track.artist, song: track.title)
    }

    private func playSongItem(_ songItem: Song) async throws -> Track {
        player.queue = [songItem]
        try await player.prepareToPlay()
        try await player.play()

        let playingTrack = Track(
            title: songItem.title,
            artist: songItem.artistName,
            album: songItem.albumTitle ?? "",
            artworkURL: songItem.artwork?.url(width: 300, height: 300),
            duration: songItem.duration ?? 0,
            serviceIDs: .init(appleMusic: songItem.id.rawValue)
        )

        self.currentTrack = playingTrack
        isPlaying = true
        startMonitoring()

        return playingTrack
    }
    
    public func search(query: String) async throws -> [Track] {
        let searchRequest = MusicCatalogSearchRequest(term: query, types: [Song.self])
        let response = try await searchRequest.response()
        
        return response.songs.map { songItem in
            Track(
                title: songItem.title,
                artist: songItem.artistName,
                album: songItem.albumTitle ?? "",
                artworkURL: songItem.artwork?.url(width: 300, height: 300),
                duration: songItem.duration ?? 0,
                serviceIDs: .init(appleMusic: songItem.id.rawValue)
            )
        }
    }
	
	public func pause() {
		player.pause()
        isPlaying = false
        stopMonitoring()
	}
	
	public func unpause() async throws {
		try await player.play()
        isPlaying = true
        startMonitoring()
	}
	
	public func stop() {
		player.stop()
		player.playbackTime = 0
        isPlaying = false
        currentPlaybackTime = 0
        stopMonitoring()
	}
    
    public func seek(to time: TimeInterval) {
        player.playbackTime = time
        currentPlaybackTime = time
    }
    
    private func startMonitoring() {
        stopMonitoring()
        // Keep this task on the main actor so all accesses to self are serialized.
        playbackMonitorTask = Task { @MainActor in
            while true {
                do {
                    try await Task.sleep(for: .seconds(0.5))
                } catch {
                    print("AppleMusic playback monitor sleep failed: \(error)")
                }
                guard !Task.isCancelled else { break }
                
                let status = self.player.state.playbackStatus
                if status == .stopped || status == .paused || status == .interrupted {
                    if self.isPlaying {
                        self.isPlaying = false
                        self.stopMonitoring()
                        break
                    }
                }
                self.currentPlaybackTime = self.player.playbackTime
            }
        }
    }
    
    private func stopMonitoring() {
        playbackMonitorTask?.cancel()
        playbackMonitorTask = nil
    }
}

enum AppleMusicError: Error {
    case songNotFound
}
