import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognizer: ObservableObject {
	@Published var transcript: String = ""
	@Published var isRecording: Bool = false
	@Published var errorMessage: String? = nil
	
	private var recognitionTask: SFSpeechRecognitionTask?
	private let speechRecognizer = SFSpeechRecognizer()
	private let audioEngine = AVAudioEngine()
	private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	
	func startTranscribing() {
		guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
			self.errorMessage = "Speech recognizer is not available."
			return
		}
		
		SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
			DispatchQueue.main.async {
				guard let self = self else { return }
				switch authStatus {
					case .authorized:
						do {
							try self.startRecording()
						} catch {
							self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
						}
					case .denied, .restricted, .notDetermined:
						self.errorMessage = "Speech recognition authorization denied or restricted."
					@unknown default:
						self.errorMessage = "Unknown authorization status."
				}
			}
		}
	}
	
	func stopTranscribing() {
		audioEngine.stop()
		audioEngine.inputNode.removeTap(onBus: 0)
		recognitionRequest?.endAudio()
		recognitionTask?.cancel()
		recognitionTask = nil
		isRecording = false
	}
	
	private func startRecording() throws {
		// Cancel existing task
		if let recognitionTask = recognitionTask {
			recognitionTask.cancel()
			self.recognitionTask = nil
		}
		
		let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
		try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
		
		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
		guard let recognitionRequest = recognitionRequest else {
			fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
		}
		
		recognitionRequest.shouldReportPartialResults = true
		
		let inputNode = audioEngine.inputNode
		// Remove any existing tap to avoid "nullptr == Tap()" crash
		inputNode.removeTap(onBus: 0)
		
		recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
			guard let self = self else { return }
			
			var isFinal = false
			
			if let result = result {
				self.transcript = result.bestTranscription.formattedString
				print("Recognized: \(self.transcript)")
				isFinal = result.isFinal
			}
			
			if error != nil || isFinal {
				self.audioEngine.stop()
				inputNode.removeTap(onBus: 0)
				
				self.recognitionRequest = nil
				self.recognitionTask = nil
				self.isRecording = false
			}
		}
		
		let recordingFormat = inputNode.outputFormat(forBus: 0)
		inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
			recognitionRequest.append(buffer)
		}
		
		audioEngine.prepare()
		try audioEngine.start()
		
		isRecording = true
		errorMessage = nil
	}
}
