//
//  MusicPlayer.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation

import SwiftData

public struct StreamingServiceIDs: Codable, Hashable {
    public var appleMusic: String?
    public var spotify: String?
    public var youtube: String?
    public var tidal: String?
    
    public init(appleMusic: String? = nil, spotify: String? = nil, youtube: String? = nil, tidal: String? = nil) {
        self.appleMusic = appleMusic
        self.spotify = spotify
        self.youtube = youtube
        self.tidal = tidal
    }
}

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
    public var serviceIDs: StreamingServiceIDs
    
    public init(uuid: UUID = UUID(), title: String, artist: String, album: String, artworkURL: URL? = nil, duration: TimeInterval, serviceIDs: StreamingServiceIDs = .init()) {
        self.uuid = uuid
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.serviceIDs = serviceIDs
    }
}

/// A generic interface for interacting with different streaming music providers
/// (e.g., Apple Music, Spotify, Tidal).
@MainActor
public protocol StreamingMusicProvider {
	/// Plays a specific track by artist and song name.
	@discardableResult
	func play(artist: String, song: String) async throws -> Track
    
    func play(id: StreamingServiceIDs) async throws
    
	func pause()
	var isPlaying: Bool { get }
    var currentTrack: Track? { get }
	func unpause() async throws
	func stop()
    
    var currentPlaybackTime: TimeInterval { get }
    func seek(to time: TimeInterval)
}

@Observable
@MainActor
public class MusicPlayer {
    public let provider: StreamingMusicProvider
    
    public init(provider: StreamingMusicProvider = AppleMusic()) {
        self.provider = provider
    }
    
    @discardableResult
    public func play(artist: String, song: String) async throws -> Track {
        try await provider.play(artist: artist, song: song)
    }
    
	public func play(id: StreamingServiceIDs) async throws {
        try await provider.play(id: id)
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
