//
//  AppleMusic.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation
import MusicKit

class AppleMusic: StreamingMusicProvider {
    private let player = ApplicationMusicPlayer.shared
    
    func play(track: Track) async throws {
        // Search Apple Music Catalog for the song using title and artist
        let searchTerm = "\(track.title) \(track.artist)"
        var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        searchRequest.limit = 1
        
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
            Playing: \(track.title) by \(track.artist)
            
            """)
            return
        }
        
        // Check if we found any songs
        guard let song = response.songs.first else {
            throw AppleMusicError.songNotFound
        }
        
        // Set the queue and play
        player.queue = [song]
        try await player.play()
    }
}

enum AppleMusicError: Error {
    case songNotFound
}
