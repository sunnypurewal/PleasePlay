//
//  MusicPlayer.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation
@preconcurrency import MusicKit

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
	public var previewURL: String?
	public var duration: TimeInterval

	// Provider specific IDs
	public var serviceIDs: StreamingServiceIDs
	
	public init(title: String, artist: String, album: String, artworkURL: URL? = nil, previewURL: String? = nil, duration: TimeInterval, serviceIDs: StreamingServiceIDs = .init()) {
		self.title = title
		self.artist = artist
		self.album = album
		self.artworkURL = artworkURL
		self.previewURL = previewURL
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
	private var fallbackProvider: AppleMusic?
	private var hasRequestedMusicAuthorization = false
	public var isUserPaused: Bool = false
	public var prePlayHook: (() async -> Void)?
	public var isSeeking: Bool = false
	
	public init() {
		self.provider = nil
	}
	
	public func setProvider(_ provider: StreamingMusicProvider) {
		self.provider = provider
	}
	
	@discardableResult
	public func play(artist: String, song: String) async throws -> Track {
		await requestMusicAuthorizationIfNeeded()
		let provider = await resolvedProvider()
		isUserPaused = false
		await runPrePlayHook()
		return try await provider.play(artist: artist, song: song)
	}
	
	public func play(id: StreamingServiceIDs) async throws {
		await requestMusicAuthorizationIfNeeded()
		let provider = await resolvedProvider()
		isUserPaused = false
		await runPrePlayHook()
		try await provider.play(id: id)
	}
	
	public func search(query: String) async throws -> [Track] {
		let provider = await resolvedProvider()
		return try await provider.search(query: query)
	}
	
	public func pause() {
		isUserPaused = true
		activeProvider?.pause()
	}
	public func unpause() async throws {
		await requestMusicAuthorizationIfNeeded()
		let provider = await resolvedProvider()
		isUserPaused = false
		await runPrePlayHook()
		try await provider.unpause()
	}
	
	public func stop() {
		isUserPaused = true
		activeProvider?.stop()
	}
	
	public func seek(to time: TimeInterval) {
		activeProvider?.seek(to: time)
	}
	
	public var isPlaying: Bool {
		activeProvider?.isPlaying ?? false
	}
	
	public var currentTrack: Track? {
		activeProvider?.currentTrack
	}
	
	public var currentPlaybackTime: TimeInterval {
		activeProvider?.currentPlaybackTime ?? 0
	}
	
	private func runPrePlayHook() async {
		await prePlayHook?()
	}
	
	private var activeProvider: StreamingMusicProvider? {
		provider ?? fallbackProvider
	}
	
	private func resolvedProvider() async -> StreamingMusicProvider {
		if let provider = provider {
			return provider
		}
		if fallbackProvider == nil {
			fallbackProvider = AppleMusic()
		}
		return fallbackProvider!
	}
	
	private func requestMusicAuthorizationIfNeeded() async {
		guard !hasRequestedMusicAuthorization else { return }
		let status = MusicAuthorization.currentStatus
		if status == .notDetermined {
			_ = await MusicAuthorization.request()
		}
		hasRequestedMusicAuthorization = true
	}
}

public enum MusicPlayerError: Error {
	case providerNotSet
}
