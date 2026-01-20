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
public class Track {
	public var uuid: UUID
	public var title: String
	public var artist: String
	public var album: String
	public var artworkURL: URL?
	public var duration: TimeInterval
    
    // Provider specific IDs
    public var appleMusicID: String?
    public var spotifyID: String?
    public var youTubeID: String?
    public var tidalID: String?
    
    public init(uuid: UUID = UUID(), title: String, artist: String, album: String, artworkURL: URL? = nil, duration: TimeInterval, appleMusicID: String? = nil, spotifyID: String? = nil, youTubeID: String? = nil, tidalID: String? = nil) {
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
@MainActor
public protocol StreamingMusicProvider {
	/// Plays a specific track by artist and song name.
	@discardableResult
	func play(artist: String, song: String) async throws -> Track
    
    func play(trackID: String) async throws
    
	func pause()
	var isPlaying: Bool { get }
    var currentTrack: Track? { get }
	func unpause() async throws
	func stop()
    
    var currentPlaybackTime: TimeInterval { get }
    func seek(to time: TimeInterval)
}

@MainActor
public class MusicPlayer {
    public let provider: StreamingMusicProvider
    
    public init(provider: StreamingMusicProvider) {
        self.provider = provider
    }
    
    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
        try await provider.play(artist: artist, song: song)
    }
    
    public func play(trackID: String) async throws {
        try await provider.play(trackID: trackID)
    }
    
    public func pause() {
        provider.pause()
    }
    
    public func unpause() async throws {
        try await provider.unpause()
    }
    
    public func stop() {
        provider.stop()
    }
    
    public func seek(to time: TimeInterval) {
        provider.seek(to: time)
    }
    
    public var isPlaying: Bool {
        provider.isPlaying
    }
    
    public var currentTrack: Track? {
        provider.currentTrack
    }
    
    public var currentPlaybackTime: TimeInterval {
        provider.currentPlaybackTime
    }
}
