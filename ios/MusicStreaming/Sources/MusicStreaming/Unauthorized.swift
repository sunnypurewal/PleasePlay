import AVFoundation
import Foundation
import Observation

private struct UnauthorizedTrack: Codable {
	enum CodingKeys: String, CodingKey {
		case id, title, artist, album
		case artworkURL = "artwork_url"
		case previewURL = "preview_url"
		case duration
	}

	let id: String
	let title: String
	let artist: String
	let album: String
	let artworkURL: URL?
	let previewURL: String?
	let duration: TimeInterval?

	var asTrack: Track {
		// Replace {w} and {h} placeholders with 300 if present
		let normalizedArtworkURL: URL? = {
			guard let artworkURL else { return nil }
			var urlString = artworkURL.absoluteString.removingPercentEncoding ?? artworkURL.absoluteString
			urlString = urlString.replacingOccurrences(of: "{w}", with: "300")
			urlString = urlString.replacingOccurrences(of: "{h}", with: "300")
			return URL(string: urlString)
		}()

		return Track(
			title: title,
			artist: artist,
			album: album,
			artworkURL: normalizedArtworkURL,
			previewURL: previewURL,
			duration: 30,
			serviceIDs: .init(appleMusic: id)
		)
	}
}

private enum UnauthorizedError: Error {
	case emptyQuery
	case songNotFound
	case previewUnavailable
}

@MainActor
@Observable
public class Unauthorized: StreamingMusicProvider {
	public let name: String = "Preview"
	private let player = AVPlayer()
	private var playbackMonitorTask: Task<Void, Never>?

	public var isPlaying: Bool = false
	public var currentTrack: Track?
	public var currentPlaybackTime: TimeInterval = 0

	public init() {}

	public func play(artist: String, song: String) async throws -> Track {
		let query = [artist, song]
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
			.joined(separator: " ")

		guard !query.isEmpty else {
			throw UnauthorizedError.emptyQuery
		}

		let tracks = try await search(query: query)
		guard let track = tracks.first else {
			throw UnauthorizedError.songNotFound
		}

		return try playPreview(for: track)
	}

	@discardableResult
	public func play(track: Track) async throws -> Track {
		return try playPreview(for: track)
	}

	private func playPreview(for track: Track) throws -> Track {
		guard let previewURLString = track.previewURL,
			  let previewURL = URL(string: previewURLString) else {
			throw UnauthorizedError.previewUnavailable
		}

		let playerItem = AVPlayerItem(url: previewURL)
		player.replaceCurrentItem(with: playerItem)
		player.volume = 1.0
		player.play()
		currentPlaybackTime = 0

		currentTrack = track
		isPlaying = true
		startMonitoring()

		return track
	}

	public func search(query: String) async throws -> [Track] {
		let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedQuery.isEmpty else {
			return []
		}

		var components = URLComponents(string: "https://w4w5iv0ad5.execute-api.us-east-1.amazonaws.com/staging/search")
		components?.queryItems = [URLQueryItem(name: "term", value: trimmedQuery)]
		guard let url = components?.url else {
			throw URLError(.badURL)
		}

		let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
		guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
			throw URLError(.badServerResponse)
		}

		let decoder = JSONDecoder()
		let payload = try decoder.decode([UnauthorizedTrack].self, from: data)
		return payload.map { $0.asTrack }
	}

	public func getTopSongs(for artist: String) async throws -> [Track] {
		return try await search(query: artist)
	}

	public func getAlbums(for artist: String) async throws -> [Album] {
		return []
	}

	public func pause() {
		player.pause()
		isPlaying = false
		stopMonitoring()
	}

	public func unpause() async throws {
		player.play()
		isPlaying = true
		startMonitoring()
	}

	public func stop() {
		player.pause()
		player.seek(to: .zero)
		isPlaying = false
		currentTrack = nil
		currentPlaybackTime = 0
		stopMonitoring()
	}

	public func seek(to time: TimeInterval) {
		let cmTime = CMTime(seconds: time, preferredTimescale: 1_000_000)
		player.seek(to: cmTime)
		currentPlaybackTime = time
	}

	private func startMonitoring() {
		stopMonitoring()
		playbackMonitorTask = Task { @MainActor in
			while true {
				do {
					try await Task.sleep(for: .seconds(0.5))
				} catch {
					if error is CancellationError {
						break
					}
					print("Playback monitor sleep failed: \(error)")
				}
				guard !Task.isCancelled else { break }

				isPlaying = player.timeControlStatus == .playing

				currentPlaybackTime = player.currentTime().seconds

				if player.timeControlStatus == .paused,
				   let item = player.currentItem,
				   item.asset.duration.isValid {
					let durationSeconds = item.asset.duration.seconds
					if durationSeconds.isFinite && player.currentTime().seconds >= durationSeconds {
						isPlaying = false
						await player.seek(to: .zero) // Reset playback so play restarts from start after completion
						currentPlaybackTime = 0
						break
					}
				}
			}
			if Task.isCancelled {
				playbackMonitorTask = nil
				return
			}
			playbackMonitorTask = nil
		}
	}

	private func stopMonitoring() {
		playbackMonitorTask?.cancel()
		playbackMonitorTask = nil
	}
}
