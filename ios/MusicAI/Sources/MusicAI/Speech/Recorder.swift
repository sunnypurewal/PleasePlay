/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 Audio input code
 */

import Foundation
import AVFoundation
import SwiftUI

@Observable
public class Recorder {
	private var outputContinuation: AsyncStream<AudioData>.Continuation? = nil
	private let audioEngine: AVAudioEngine
	private let transcriber: SpokenWordTranscriber
	var file: AVAudioFile?
	private let url: URL
    
    public var isRecording: Bool = false
	
	public init(transcriber: SpokenWordTranscriber) {
		audioEngine = AVAudioEngine()
		self.transcriber = transcriber
		self.url = FileManager.default.temporaryDirectory
			.appending(component: UUID().uuidString)
			.appendingPathExtension(for: .wav)
	}
	
	private func setup() async throws {
		guard await isMicrophoneAuthorized() else {
			print("user denied mic permission")
			return
		}
#if os(iOS)
		try setUpAudioSession()
#endif
		try await transcriber.setUpTranscriber()
		
        isRecording = true
		for await input in try await audioStream() {
			try await self.transcriber.streamAudioToTranscriber(input.buffer)
		}
        isRecording = false
	}
	
	public func stopRecording() async throws {
		guard isRecording else { return }
		audioEngine.stop()
		isRecording = false
		try await transcriber.finishTranscribing()
#if os(iOS)
        deactivateAudioSession()
#endif
	}
	
	public func pauseRecording() {
		guard isRecording else { return }
		audioEngine.pause()
        isRecording = false
#if os(iOS)
        deactivateAudioSession()
#endif
	}
	
	public func record() async throws {
		guard !isRecording else { return }
        if outputContinuation == nil {
            try await setup()
        }
#if os(iOS)
        try setUpAudioSession()
#endif
		try audioEngine.start()
        isRecording = true
	}

    public func toggleRecording() async throws {
        if isRecording {
            pauseRecording()
        } else {
            try await record()
        }
    }
#if os(iOS)
	func setUpAudioSession() throws {
		let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
		try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
	}

    func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
#endif
	
	private func audioStream() async throws -> AsyncStream<AudioData> {
		try setupAudioEngine()
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Check if the format is valid (Simulator workaround)
        let tapFormat: AVAudioFormat
        if format.sampleRate == 0 || format.channelCount == 0 {
            // Fallback to a standard format if the input node reports invalid data
            if let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                tapFormat = standardFormat
            } else {
                // If even standard format fails, return empty stream (or throw, but let's be safe)
                return AsyncStream { _ in }
            }
        } else {
            tapFormat = format
        }
        
		inputNode.installTap(onBus: 0,
										 bufferSize: 4096,
										 format: tapFormat) { [weak self] (buffer, time) in
			guard let self else { return }
            if let copy = buffer.copy() as? AVAudioPCMBuffer {
                self.outputContinuation?.yield(AudioData(buffer: copy, time: time))
            }
		}
		
		audioEngine.prepare()
		try audioEngine.start()
		
		return AsyncStream(AudioData.self) {
			continuation in
			outputContinuation = continuation
		}
	}
	
	private func setupAudioEngine() throws {
#if os(iOS)
        try setUpAudioSession()
#endif
        let inputNode = audioEngine.inputNode
        var format = inputNode.outputFormat(forBus: 0)
        
        // Use standard format settings if the node's format is invalid
        if format.sampleRate == 0 || format.channelCount == 0 {
             if let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                 format = standardFormat
             }
        }
        
		let inputSettings = format.settings
		self.file = try AVAudioFile(forWriting: url,
									settings: inputSettings)
		
		inputNode.removeTap(onBus: 0)
	}
	
	
}
