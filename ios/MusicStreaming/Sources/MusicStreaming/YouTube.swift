//
//  YouTube.swift
//  MusicStreaming
//
//  Created by Gemini on 2026-01-21.
//

import Foundation
import Observation

@MainActor
@Observable
public class YouTube: StreamingMusicProvider {
    public var isPlaying: Bool = false
    public var currentTrack: Track?
    public var currentPlaybackTime: TimeInterval = 0

    public init() {}
    
    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
        let track = Track(title: song, artist: artist, album: "", duration: 0)
        self.currentTrack = track
        return track
    }
    
    public func play(id: StreamingServiceIDs) async throws {
    }
    
    public func search(query: String) async throws -> [Track] {
        return []
    }
    
    public func pause() {
    }
    
    public func unpause() async throws {
    }
    
    public func stop() {
    }
    
    public func seek(to time: TimeInterval) {
    }
}
