import Foundation

public struct MusicRecognitionResult: Sendable, Equatable {
    public let id: String?
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkUrl: URL?
    public let storefrontId: String?
    public let recognizedAt: Date

    public init(
        id: String? = nil,
        title: String,
        artist: String,
        album: String?,
        artworkUrl: URL?,
        storefrontId: String?,
        recognizedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkUrl = artworkUrl
        self.storefrontId = storefrontId
        self.recognizedAt = recognizedAt
    }
}

public protocol MusicRecognitionProtocol {
    func recognizeSingleSong() async throws -> MusicRecognitionResult

    func startContinuousRecognition(
        for duration: TimeInterval?,
        onRecognition: @escaping @Sendable (MusicRecognitionResult) -> Void
    ) async throws

    func stopContinuousRecognition() async

}
