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
public struct Track: Equatable {
	public var title: String
	public var artist: String
	public var album: String
	public var artworkURL: URL?
	public var previewURL: String?
	public var duration: TimeInterval

	// Provider specific IDs
	public var serviceIDs: StreamingServiceIDs
	public var isExplicit: Bool

	public init(title: String, artist: String, album: String, artworkURL: URL? = nil, previewURL: String? = nil, duration: TimeInterval, serviceIDs: StreamingServiceIDs = .init(), isExplicit: Bool = false) {
		self.title = title
		self.artist = artist
		self.album = album
		self.artworkURL = artworkURL
		self.previewURL = previewURL
		self.duration = duration
		self.serviceIDs = serviceIDs
		self.isExplicit = isExplicit
	}

	public static func == (lhs: Track, rhs: Track) -> Bool {
		return lhs.title == rhs.title
			&& lhs.artist == rhs.artist
			&& lhs.album == rhs.album
			&& lhs.artworkURL == rhs.artworkURL
			&& lhs.previewURL == rhs.previewURL
			&& lhs.duration == rhs.duration
			&& lhs.serviceIDs == rhs.serviceIDs
			&& lhs.isExplicit == rhs.isExplicit
	}
}

/// A generic interface for interacting with different streaming music providers
/// (e.g., Apple Music, Spotify, Tidal).
@MainActor
public protocol StreamingMusicProvider {
	var name: String { get }
	/// Plays a specific track by artist and song name.
	@discardableResult
	func play(artist: String, song: String) async throws -> Track
	
	@discardableResult
	func play(track: Track) async throws -> Track
	
	func search(query: String) async throws -> [Track]
	func getTopSongs(for artist: String) async throws -> [Track]
	
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
	private var provider: StreamingMusicProvider
	private var fallbackProvider: AppleMusic?
	public var isUserPaused: Bool = false
	public var prePlayHook: (() async -> Void)?
	public var isSeeking: Bool = false
	public private(set) var isPlaying: Bool = false {
		didSet {
			if oldValue != isPlaying {
				onIsPlayingChange?(isPlaying)
			}
		}
	}
	public var onIsPlayingChange: ((Bool) -> Void)?
	
	public var providerName: String {
		activeProvider?.name ?? "None"
	}
	
	public init(provider: StreamingMusicProvider = Unauthorized()) {
		self.provider = provider
		startProviderPlaybackMonitor()
	}
	
	public func setProvider(_ provider: StreamingMusicProvider) {
		self.provider = provider
		updatePlayingState()
		startProviderPlaybackMonitor()
	}
	
	@discardableResult
	public func play(artist: String, song: String) async throws -> Track {
		isUserPaused = false
		await runPrePlayHook()
		let track = try await provider.play(artist: artist, song: song)
		updatePlayingState()
		return track
	}

	@discardableResult
	public func play(track: Track) async throws -> Track {
		isUserPaused = false
		await runPrePlayHook()
		let playedTrack = try await provider.play(track: track)
		updatePlayingState()
		return playedTrack
	}

	public func search(query: String) async throws -> [Track] {
		return try await provider.search(query: query)
	}

	public func getTopSongs(for artist: String) async throws -> [Track] {
		return try await provider.getTopSongs(for: artist)
	}
	
	public func pause() {
		isUserPaused = true
		activeProvider?.pause()
		updatePlayingState()
	}
	public func unpause() async throws {
		isUserPaused = false
		await runPrePlayHook()
		try await provider.unpause()
		updatePlayingState()
	}

	public func stop() {
		isUserPaused = true
		activeProvider?.stop()
		updatePlayingState()
	}
	
	public func seek(to time: TimeInterval) {
		activeProvider?.seek(to: time)
	}

	public private(set) var currentTrack: Track?
	
	public var currentPlaybackTime: TimeInterval {
		activeProvider?.currentPlaybackTime ?? 0
	}
	
	private func runPrePlayHook() async {
		await prePlayHook?()
	}
	
	private var activeProvider: StreamingMusicProvider? {
		provider ?? fallbackProvider
	}

	private func updatePlayingState() {
		let newValue = activeProvider?.isPlaying ?? false
		if isPlaying != newValue {
			isPlaying = newValue
		}
		refreshCurrentTrackIfNeeded()
	}

	private func refreshCurrentTrackIfNeeded() {
		if let providerTrack = activeProvider?.currentTrack {
			if currentTrack != providerTrack {
				currentTrack = providerTrack
			}
		} else if currentTrack != nil {
			currentTrack = nil
		}
	}

	private var providerPlaybackMonitorTask: Task<Void, Never>?

	private func startProviderPlaybackMonitor() {
		stopProviderPlaybackMonitor()
		providerPlaybackMonitorTask = Task { @MainActor [weak self] in
			while true {
				do {
					try await Task.sleep(for: .milliseconds(300))
				} catch {
					break
				}
				guard !Task.isCancelled else { break }
				guard let strongSelf = self else { break }
				strongSelf.updatePlayingState()
			}
			if let strongSelf = self {
				strongSelf.providerPlaybackMonitorTask = nil
			}
		}
	}

	private func stopProviderPlaybackMonitor() {
		providerPlaybackMonitorTask?.cancel()
		providerPlaybackMonitorTask = nil
	}
}

public enum MusicPlayerError: Error {
	case providerNotSet
}
