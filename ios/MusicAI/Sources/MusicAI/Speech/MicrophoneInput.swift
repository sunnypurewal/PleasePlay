/*
 See the LICENSE.txt file for this sample’s licensing information.

 Abstract:
 Microphone capture actor that exposes an AsyncStream of audio buffers.
 */

import Foundation
import AVFoundation

public actor MicrophoneInput {
    public enum MicrophoneInputError: Error {
        case microphoneAccessDenied
        case invalidAudioFormat
    }

    private let audioEngine: AVAudioEngine
    private var outputContinuation: AsyncStream<AudioData>.Continuation?
    private var currentStream: AsyncStream<AudioData>?

    public private(set) var isStreaming: Bool = false

    public init() {
        audioEngine = AVAudioEngine()
    }

    /// Starts feeding the AsyncStream with audio buffers.
    public func startStreaming() async throws -> AsyncStream<AudioData> {
        if let stream = currentStream {
            return stream
        }

        guard await isMicrophoneAuthorized() else {
            throw MicrophoneInputError.microphoneAccessDenied
        }

#if os(iOS)
        try setUpAudioSession()
#endif
        let stream = try createStream()
        currentStream = stream
        return stream
    }

    /// Stops the microphone capture and finishes the stream.
    public func stopStreaming() async {
        guard isStreaming else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
#if os(iOS)
        deactivateAudioSession()
#endif

        isStreaming = false
        outputContinuation?.finish()
        outputContinuation = nil
        currentStream = nil
    }

    private func createStream() throws -> AsyncStream<AudioData> {
        prepareAudioEngine()

        let inputNode = audioEngine.inputNode
        guard let tapFormat = makeTapFormat(from: inputNode.outputFormat(forBus: 0)) else {
            throw MicrophoneInputError.invalidAudioFormat
        }

        // A tiny Sendable box to carry the copied buffer across the detached hop.
        @preconcurrency
        final class BufferBox: @unchecked Sendable {
            let buffer: AVAudioPCMBuffer
            let time: AVAudioTime
            init(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
                self.buffer = buffer
                self.time = time
            }
        }

        // Avoid capturing actor-isolated self in the sending closure.
        // Copy the buffer on the real-time thread, then hop to the actor via a detached task.
        inputNode.installTap(onBus: 0,
                             bufferSize: 4096,
                             format: tapFormat) { [weak owner = self] buffer, time in
            // Real-time audio thread: keep work minimal and avoid touching actor state directly.
            guard let copy = buffer.copy() as? AVAudioPCMBuffer else { return }

            // Wrap the copied buffer in a Sendable box before crossing concurrency domains.
            let boxed = BufferBox(buffer: copy, time: time)

            // Hop to the actor in a detached task without capturing the actor in this sending closure.
            Task.detached { [owner, boxed] in
                guard let owner else { return }
                await owner.yieldFromTap(buffer: boxed.buffer, time: boxed.time)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isStreaming = true

        return AsyncStream(AudioData.self) { continuation in
            outputContinuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.stopStreaming() }
            }
        }
    }

    // Actor-isolated hop target to safely access actor state from the tap.
    private func yieldFromTap(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isStreaming else { return }
        outputContinuation?.yield(AudioData(buffer: buffer, time: time))
    }

    private func prepareAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func makeTapFormat(from format: AVAudioFormat) -> AVAudioFormat? {
        if format.sampleRate == 0 || format.channelCount == 0 {
            return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        }

        return format
    }

#if os(iOS)
    private func setUpAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
#endif
}
