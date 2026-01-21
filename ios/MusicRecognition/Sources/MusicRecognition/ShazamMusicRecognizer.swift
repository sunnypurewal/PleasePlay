import AVFoundation
import Foundation
import ShazamKit

public enum MusicRecognitionError: Error {
    case alreadyRunning
    case notRunning
    case noMatchFound
    case microphonePermissionDenied
    case audioEngineStartFailed
}

public actor ShazamMusicRecognizer: MusicRecognitionProtocol {
    private let session: SHSession
    private let audioEngine: AVAudioEngine
    private let audioSession: AVAudioSession
    private let sessionDelegate: SessionDelegate
    private var onRecognition: (@Sendable (MusicRecognitionResult) -> Void)?
    private var singleContinuation: CheckedContinuation<MusicRecognitionResult, Error>?
    private var stopTask: Task<Void, Never>?
    private var isRunning = false
    private var didWireDelegates = false
    private var recognizedKeys = Set<String>()

    public init() {
        self.session = SHSession()
        self.audioEngine = AVAudioEngine()
        self.audioSession = AVAudioSession.sharedInstance()
        self.sessionDelegate = SessionDelegate()
        // Delegate wiring deferred until actor-isolated context.
    }

    public func recognizeSingleSong() async throws -> MusicRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            guard singleContinuation == nil else {
                continuation.resume(throwing: MusicRecognitionError.alreadyRunning)
                return
            }
            singleContinuation = continuation

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.startContinuousRecognition(for: nil) { result in
                        Task { await self.completeSingleRecognition(with: .success(result)) }
                    }
                } catch {
                    await self.completeSingleRecognition(with: .failure(error))
                }
            }
        }
    }

    public func startContinuousRecognition(
        for duration: TimeInterval?,
        onRecognition: @escaping @Sendable (MusicRecognitionResult) -> Void
    ) async throws {
        guard !isRunning else {
            throw MusicRecognitionError.alreadyRunning
        }
        recognizedKeys.removeAll()
        self.onRecognition = onRecognition

        // Ensure delegates are wired in an actor-isolated context.
        if !didWireDelegates {
            sessionDelegate.owner = self
            session.delegate = sessionDelegate
            didWireDelegates = true
        }

        do {
            try await configureAudioSessionIfNeeded()
            try startAudioEngine()
            isRunning = true
        } catch {
            self.onRecognition = nil
            isRunning = false
            throw error
        }

        if let duration {
            stopTask?.cancel()
            stopTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await self?.stopContinuousRecognition()
            }
        }
    }

    public func stopContinuousRecognition() async {
        guard isRunning else {
            return
        }
        isRunning = false
        onRecognition = nil
        stopTask?.cancel()
        stopTask = nil

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        try? audioSession.setActive(false)
    }

    private func configureAudioSessionIfNeeded() async throws {
        if AVAudioApplication.shared.recordPermission == .undetermined {
			let granted = await AVAudioApplication.requestRecordPermission()
            if !granted {
                throw MusicRecognitionError.microphonePermissionDenied
            }
        } else if AVAudioApplication.shared.recordPermission != .granted {
            throw MusicRecognitionError.microphonePermissionDenied
        }

        try audioSession.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
        try audioSession.setActive(true)
    }

    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let session = self.session
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, time in
            session.matchStreamingBuffer(buffer, at: time)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw MusicRecognitionError.audioEngineStartFailed
        }
    }

    private func completeSingleRecognition(with result: Result<MusicRecognitionResult, Error>) {
        let continuation = singleContinuation
        singleContinuation = nil

        guard let continuation else { return }
        Task { [result] in
            await stopContinuousRecognition()
            continuation.resume(with: result)
        }
    }

    fileprivate func handleMatch(_ match: SHMatch) {
        guard let mediaItem = match.mediaItems.first else {
            if singleContinuation != nil {
                completeSingleRecognition(with: .failure(MusicRecognitionError.noMatchFound))
            }
            return
        }

        let matchKey = recognitionKey(for: mediaItem)
        if recognizedKeys.contains(matchKey) {
            return
        }
        recognizedKeys.insert(matchKey)

        let result = MusicRecognitionResult(
            title: mediaItem.title ?? "Unknown Title",
            artist: mediaItem.artist ?? "Unknown Artist",
            album: mediaItem.subtitle ?? "Unknown Album",
            artworkUrl: mediaItem.artworkURL,
            storefrontId: mediaItem.appleMusicID
        )
        onRecognition?(result)

        if singleContinuation != nil {
            completeSingleRecognition(with: .success(result))
        }
    }

    fileprivate func handleNoMatch(error: Error?) {
        if let error, singleContinuation != nil {
            completeSingleRecognition(with: .failure(error))
        }
    }

    private func recognitionKey(for mediaItem: SHMediaItem) -> String {
        if let appleMusicID = mediaItem.appleMusicID, !appleMusicID.isEmpty {
            return "am:\(appleMusicID)"
        }
        let title = mediaItem.title?.lowercased() ?? "unknown-title"
        let artist = mediaItem.artist?.lowercased() ?? "unknown-artist"
        let album = mediaItem.subtitle?.lowercased() ?? "unknown-album"
        return "meta:\(title)|\(artist)|\(album)"
    }
}

@preconcurrency
private final class SessionDelegate: NSObject, SHSessionDelegate {
    weak var owner: ShazamMusicRecognizer?

    func session(_ session: SHSession, didFind match: SHMatch) {
        // Hop to the actor explicitly from a detached task to avoid capturing isolated state in a sending closure.
        let owner = self.owner
        Task.detached { [owner, match] in
            await owner?.handleMatch(match)
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        let owner = self.owner
        Task.detached { [owner, error] in
            await owner?.handleNoMatch(error: error)
        }
    }
}
