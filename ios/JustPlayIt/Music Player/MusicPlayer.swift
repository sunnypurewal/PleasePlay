//
//  MusicPlayer.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation

import SwiftData

/// Represents a music track with basic metadata.
@Model
class Track {
	var uuid: UUID
	var title: String
	var artist: String
	var album: String
	var artworkURL: URL?
	var duration: TimeInterval
    
    // Provider specific IDs
    var appleMusicID: String?
    var spotifyID: String?
    var youTubeID: String?
    var tidalID: String?
    
    init(uuid: UUID = UUID(), title: String, artist: String, album: String, artworkURL: URL? = nil, duration: TimeInterval, appleMusicID: String? = nil, spotifyID: String? = nil, youTubeID: String? = nil, tidalID: String? = nil) {
        self.uuid = uuid
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.appleMusicID = appleMusicID
        self.spotifyID = spotifyID
        self.youTubeID = youTubeID
        self.tidalID = tidalID
    }
}

/// A generic interface for interacting with different streaming music providers
/// (e.g., Apple Music, Spotify, Tidal).
protocol StreamingMusicProvider {
	/// Plays a specific track by artist and song name.
	@discardableResult
	func play(artist: String, song: String) async throws -> Track
    
    func play(track: Track) async throws
    
	func pause()
	var isPlaying: Bool { get }
    var currentTrack: Track? { get }
	func unpause() async throws
	func stop()
    
    var currentPlaybackTime: TimeInterval { get }
    func seek(to time: TimeInterval)
}
