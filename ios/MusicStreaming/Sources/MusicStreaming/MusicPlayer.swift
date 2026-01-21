//
//  MusicPlayer.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation

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
public class Track {
	public var title: String
	public var artist: String
	public var album: String
	public var artworkURL: URL?
	public var duration: TimeInterval
	
	// Provider specific IDs
	public var serviceIDs: StreamingServiceIDs
	
	public init(title: String, artist: String, album: String, artworkURL: URL? = nil, duration: TimeInterval, serviceIDs: StreamingServiceIDs = .init()) {
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
	
	func search(query: String) async throws -> [Track]
	
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
	public var provider: StreamingMusicProvider?
	
	public init() {
		self.provider = nil
	}
	
	public func setProvider(_ provider: StreamingMusicProvider) {
		self.provider = provider
	}
	
	@discardableResult
	public func play(artist: String, song: String) async throws -> Track {
		guard let provider = provider else { throw MusicPlayerError.providerNotSet }
		return try await provider.play(artist: artist, song: song)
	}
	
	public func play(id: StreamingServiceIDs) async throws {
		guard let provider = provider else { throw MusicPlayerError.providerNotSet }
		try await provider.play(id: id)
	}
	
	public func search(query: String) async throws -> [Track] {
		guard let provider = provider else { throw MusicPlayerError.providerNotSet }
		return try await provider.search(query: query)
	}
	
	public func pause() {
		provider?.pause()
	}
	public func unpause() async throws {
		guard let provider = provider else { return }
		try await provider.unpause()
	}
	
	public func stop() {
		provider?.stop()
	}
	
	public func seek(to time: TimeInterval) {
		provider?.seek(to: time)
	}
	
	public var isPlaying: Bool {
		provider?.isPlaying ?? false
	}
	
	public var currentTrack: Track? {
		provider?.currentTrack
	}
	
	public var currentPlaybackTime: TimeInterval {
		provider?.currentPlaybackTime ?? 0
	}
}

public enum MusicPlayerError: Error {
	case providerNotSet
}
