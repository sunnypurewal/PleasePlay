//
//  MusicPlayer.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import Foundation

/// Represents a music track with basic metadata.
struct Track: Identifiable, Sendable {
	let id: UUID
	let title: String
	let artist: String
	let album: String
	let artworkURL: URL?
	let duration: TimeInterval
}

/// A generic interface for interacting with different streaming music providers
/// (e.g., Apple Music, Spotify, Tidal).
protocol StreamingMusicProvider {
	/// Plays a specific track by artist and song name.
	@discardableResult
	func play(artist: String, song: String) async throws -> Track
	func pause()
	var isPlaying: Bool { get }
	func unpause() async throws
	func stop()
    
    var currentPlaybackTime: TimeInterval { get }
    func seek(to time: TimeInterval)
}
