/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 Audio input code
 */

import Foundation
import AVFoundation
import SwiftUI

public class Recorder {
	private var outputContinuation: AsyncStream<AudioData>.Continuation? = nil
	private let audioEngine: AVAudioEngine
	private let transcriber: SpokenWordTranscriber
	var playerNode: AVAudioPlayerNode?
	
	var file: AVAudioFile?
	private let url: URL
	
	public init(transcriber: SpokenWordTranscriber) {
		audioEngine = AVAudioEngine()
		self.transcriber = transcriber
		self.url = FileManager.default.temporaryDirectory
			.appending(component: UUID().uuidString)
			.appendingPathExtension(for: .wav)
	}
	
	public func record() async throws {
		guard await isAuthorized() else {
			print("user denied mic permission")
			return
		}
#if os(iOS)
		try setUpAudioSession()
#endif
		try await transcriber.setUpTranscriber()
		
		for await input in try await audioStream() {
			try await self.transcriber.streamAudioToTranscriber(input.buffer)
		}
	}
	
	public func stopRecording() async throws {
		audioEngine.stop()
		
		try await transcriber.finishTranscribing()
		
		Task {
			// self.story.title.wrappedValue = try await story.wrappedValue.suggestedTitle() ?? story.title.wrappedValue
		}
		
	}
	
	public func pauseRecording() {
		audioEngine.pause()
	}
	
	public func resumeRecording() throws {
		try audioEngine.start()
	}
#if os(iOS)
	func setUpAudioSession() throws {
		let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
		try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
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
			writeBufferToDisk(buffer: buffer)
            if let copy = buffer.copy() as? AVAudioPCMBuffer {
                self.outputContinuation?.yield(AudioData(buffer: copy, time: time))
            }
		}
		
		audioEngine.prepare()
		try audioEngine.start()
		
		return AsyncStream(AudioData.self, bufferingPolicy: .unbounded) {
			continuation in
			outputContinuation = continuation
		}
	}
	
	private func setupAudioEngine() throws {
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
	
	public func playRecording() {
		guard let file else {
			return
		}
		
		playerNode = AVAudioPlayerNode()
		guard let playerNode else {
			return
		}
		
		audioEngine.attach(playerNode)
		audioEngine.connect(playerNode,
							to: audioEngine.outputNode,
							format: file.processingFormat)
		
		playerNode.scheduleFile(file,
								at: nil,
								completionCallbackType: .dataPlayedBack) { _ in
		}
		
		do {
			try audioEngine.start()
			playerNode.play()
		} catch {
			print("error")
		}
	}
	
	public func stopPlaying() {
		audioEngine.stop()
	}
}
