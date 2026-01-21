import MusicRecognition
import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recognizer = ShazamMusicRecognizer()
    @State private var isRecognizing = false
    @State private var isContinuousRecognizing = false
    @State private var isTimedRecognizing = false
    @State private var continuousStopTask: Task<Void, Never>?
    @State private var recognitionResult: MusicRecognitionResult?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Discover")
                    .font(.title2.weight(.semibold))
                Text("Find new music and curated picks here soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await recognizeSong()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text(isRecognizing ? "Listening..." : "Recognize Song")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecognizing || isContinuousRecognizing)

            Button {
                Task {
                    await toggleContinuousRecognition()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isContinuousRecognizing ? "stop.circle" : "waveform.circle")
                    Text(isContinuousRecognizing ? "Stop Listening" : "Listen Continuously")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isContinuousRecognizing ? .red : .blue)
            .disabled(isRecognizing)

            Button {
                Task {
                    await startTimedRecognition(duration: 3_600)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(isTimedRecognizing ? "Listening (1 hour)" : "Listen for 1 hour")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRecognizing || isContinuousRecognizing)

            if let recognitionResult {
                HStack(spacing: 12) {
                    if let artworkUrl = recognitionResult.artworkUrl {
                        AsyncImage(url: artworkUrl) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recognitionResult.title)
                            .font(.headline)
                        Text(recognitionResult.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let album = recognitionResult.album, !album.isEmpty {
                            Text(album)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func recognizeSong() async {
        isRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        do {
            let result = try await recognizer.recognizeSingleSong()
            recognitionResult = result
            await addToHistory(from: result)
        } catch {
            errorMessage = "Recognition failed. \(error.localizedDescription)"
        }
        isRecognizing = false
    }

    private func toggleContinuousRecognition() async {
        if isContinuousRecognizing {
            continuousStopTask?.cancel()
            continuousStopTask = nil
            isTimedRecognizing = false
            await recognizer.stopContinuousRecognition()
            isContinuousRecognizing = false
            return
        }

        isContinuousRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        do {
            try await recognizer.startContinuousRecognition(for: nil) { result in
                Task { @MainActor in
                    recognitionResult = result
                    addToHistory(from: result)
                }
            }
        } catch {
            errorMessage = "Recognition failed. \(error.localizedDescription)"
            isContinuousRecognizing = false
        }
    }

    private func startTimedRecognition(duration: TimeInterval) async {
        guard !isContinuousRecognizing else { return }
        isTimedRecognizing = true
        isContinuousRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        continuousStopTask?.cancel()
        continuousStopTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                isContinuousRecognizing = false
                isTimedRecognizing = false
            }
        }
        do {
            try await recognizer.startContinuousRecognition(for: duration) { result in
                Task { @MainActor in
                    recognitionResult = result
                    addToHistory(from: result)
                }
            }
        } catch {
            errorMessage = "Recognition failed. \(error.localizedDescription)"
            isContinuousRecognizing = false
            isTimedRecognizing = false
            continuousStopTask?.cancel()
            continuousStopTask = nil
        }
    }

    @MainActor
    private func addToHistory(from result: MusicRecognitionResult) {
        let serviceIDs: [MusicService: String]
        if let storefrontId = result.storefrontId {
            serviceIDs = [.appleMusic: storefrontId]
        } else {
            serviceIDs = [:]
        }

        let track = PlayedTrack(
            title: result.title,
            artist: result.artist,
            album: result.album ?? "Unknown Album",
            artworkURL: result.artworkUrl,
            duration: 0,
            serviceIDs: serviceIDs,
            lastPlayedAt: result.recognizedAt,
            playCount: 0,
            playHistory: [],
            recognizedByShazam: true,
            recognizedAt: result.recognizedAt
        )
        modelContext.insert(track)
    }
}

#Preview {
    DiscoverView()
}
