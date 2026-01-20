//
//  AppleMusic.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation
import MusicKit
import Observation

@Observable
class AppleMusic: StreamingMusicProvider {
    private let player = ApplicationMusicPlayer.shared
    var isPlaying: Bool = false
    var currentTrack: Track?
    var currentPlaybackTime: TimeInterval = 0
    private var playbackMonitorTask: Task<Void, Never>?

    // ... existing play/pause/stop/unpause updated to call startMonitoring/stopMonitoring ...
    
    @discardableResult
    func play(artist: String, song: String) async throws -> Track {
        // ... (existing search logic remains same) ...
        // Search Apple Music Catalog for the song using title and artist
        let searchTerm = "\(song) \(artist)"
        var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        
        // Execute the search
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
        
        // Check if we found any songs
        guard let songItem = response.songs.first else {
            throw AppleMusicError.songNotFound
        }
        
        // Set the queue and play
        player.queue = [songItem]
        try await player.play()
        
        let newTrack = Track(
            uuid: UUID(),
            title: songItem.title,
            artist: songItem.artistName,
            album: songItem.albumTitle ?? "",
            artworkURL: songItem.artwork?.url(width: 300, height: 300),
            duration: songItem.duration ?? 0,
            appleMusicID: songItem.id.rawValue
        )
        
        await MainActor.run { 
            self.currentTrack = newTrack
            isPlaying = true
            startMonitoring() 
        }
        
        return newTrack
    }
    
    func play(track: Track) async throws {
        if let appleMusicID = track.appleMusicID {
            // Play by ID
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(appleMusicID))
                let response = try await request.response()
                
                if let songItem = response.items.first {
                    player.queue = [songItem]
                    try await player.play()
                    
                    await MainActor.run {
                        self.currentTrack = track
                        isPlaying = true
                        startMonitoring()
                    }
                    return
                }
            } catch {
                print("Failed to play by ID: \(error). Falling back to search.")
            }
        }
        
        // Fallback to search if ID missing or not found
        _ = try await play(artist: track.artist, song: track.title)
        
        // Update currentTrack to the passed track
        await MainActor.run {
            self.currentTrack = track
        }
    }
	
	func pause() {
		player.pause()
        Task { @MainActor in isPlaying = false; stopMonitoring() }
	}
	
	func unpause() async throws {
		try await player.play()
        await MainActor.run { isPlaying = true; startMonitoring() }
	}
	
	func stop() {
		player.stop()
		player.playbackTime = 0
        Task { @MainActor in isPlaying = false; currentPlaybackTime = 0; stopMonitoring() }
	}
    
    func seek(to time: TimeInterval) {
        player.playbackTime = time
        currentPlaybackTime = time
    }
    
    private func startMonitoring() {
        stopMonitoring()
        playbackMonitorTask = Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { break }
                
                let status = self.player.state.playbackStatus
                if status == .stopped || status == .paused || status == .interrupted {
                    if self.isPlaying {
                        self.isPlaying = false
                        // We can break here, but let's just stop monitoring to be safe
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
