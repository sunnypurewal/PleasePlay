import MusicAI

public protocol AudioRecording {
	var isRecording: Bool { get }
	func record() async throws
	func stopRecording() async throws
	func toggleRecording() async throws
}

extension Recorder: AudioRecording {}
