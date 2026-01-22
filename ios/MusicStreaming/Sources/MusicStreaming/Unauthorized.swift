import Foundation

private struct UnauthorizedTrack: Codable {
	enum CodingKeys: String, CodingKey {
		case title, artist, album
		case artworkURL = "artwork_url"
		case previewURL = "preview_url"
		case duration
	}

	let title: String
	let artist: String
	let album: String
	let artworkURL: URL?
	let previewURL: String?
	let duration: TimeInterval?

	var asTrack: Track {
		Track(
			title: title,
			artist: artist,
			album: album,
			artworkURL: artworkURL,
			previewURL: previewURL,
			duration: duration ?? 0
		)
	}
}

@MainActor
public class Unauthorized: StreamingMusicProvider {
	public init() {}

	@discardableResult
	public func play(artist: String, song: String) async throws -> Track {
		throw MusicPlayerError.providerNotSet
	}

	public func play(id: StreamingServiceIDs) async throws {
		throw MusicPlayerError.providerNotSet
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

	public func pause() {}

	public var isPlaying: Bool { false }

	public var currentTrack: Track? { nil }

	public func unpause() async throws {
		throw MusicPlayerError.providerNotSet
	}

	public func stop() {}

	public var currentPlaybackTime: TimeInterval { 0 }

	public func seek(to time: TimeInterval) {}
}
