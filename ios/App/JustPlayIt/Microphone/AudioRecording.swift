import MusicAI

public protocol AudioRecording {
	var isRecording: Bool { get }
	func toggleRecording()
}

extension Recorder: AudioRecording {}
