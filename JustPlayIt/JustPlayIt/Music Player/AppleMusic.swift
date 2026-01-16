//
//  AppleMusic.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation
import MusicKit

actor AppleMusic: StreamingMusicProvider {
    
    private let player = ApplicationMusicPlayer.shared
    
    func play(track: Track) async throws {
        // Convert the generic Track ID to a MusicKit ID
		let musicItemID = MusicItemID(track.id.uuidString)
        
        // Create a request to fetch the song from the Apple Music Catalog
        var songRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
        songRequest.limit = 1
        
        // Execute the request
        let response = try await songRequest.response()
        
        // Ensure we found the song
        guard let song = response.items.first else {
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
