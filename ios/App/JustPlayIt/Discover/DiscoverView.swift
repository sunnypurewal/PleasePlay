import MusicRecognition
import SwiftData
import SwiftUI
import MusicStreaming

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var recognitionState: RecognitionListeningState
	@Environment(MusicPlayer.self) var musicPlayer
    @State private var recognizer = ShazamMusicRecognizer()
    @State private var isRecognizing = false
    @State private var singleRecognitionTask: Task<Void, Never>?
    @State private var isContinuousRecognizing = false
    @State private var isTimedRecognizing = false
    @State private var continuousStopTask: Task<Void, Never>?
    @State private var recognitionResult: MusicRecognitionResult?
    @State private var errorMessage: String?
    @State private var wasPlayingBeforeRecognition = false
    @State private var isContinuousRecognitionOnCooldown = false
    @State private var continuousRecognitionCooldownTask: Task<Void, Never>?
    private let continuousRecognitionCooldown: TimeInterval = 15
    private let activeListeningColor = Color.red

    var body: some View {
        VStack(spacing: 16) {
            LargeTitleHeader(title: "Discover")

            Button {
                Task {
                    if isRecognizing {
                        await cancelSingleRecognition()
                    } else {
                        await recognizeSong()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRecognizing ? "xmark.circle" : "waveform")
                    Text(isRecognizing ? "Cancel" : "Recognize Song")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecognizing ? activeListeningColor : .accentColor)
            .disabled(isContinuousRecognizing)

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
            .tint(isContinuousRecognizing ? activeListeningColor : .blue)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: musicPlayer.isPlaying) { _, isPlaying in
            guard isPlaying else { return }
            Task {
                await recognitionState.requestCancelRecognition(skipResume: true)
            }
        }
    }

    private func recognizeSong() async {
        wasPlayingBeforeRecognition = musicPlayer.isPlaying
        await MainActor.run {
            recognitionState.isMusicRecognitionActive = true
            recognitionState.shouldResumePlaybackAfterRecognition = true
            recognitionState.cancelRecognition = {
                await cancelSingleRecognition()
            }
        }
        isRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        singleRecognitionTask?.cancel()
        singleRecognitionTask = Task.detached {
            do {
                let result = try await recognizer.recognizeSingleSong()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    recognitionResult = result
                    recognitionState.disableAutomaticCommandListening()
                }
                await addToHistory(from: result)
            } catch is CancellationError {
                await MainActor.run {
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Recognition failed. \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isRecognizing = false
                recognitionState.isMusicRecognitionActive = false
                recognitionState.clearCancelRecognitionHandler()
                singleRecognitionTask = nil
            }
            await resumePlaybackIfNeeded()
        }
    }

    private func cancelSingleRecognition() async {
        singleRecognitionTask?.cancel()
        singleRecognitionTask = nil
        await recognizer.cancelSingleRecognition()
        await recognizer.stopContinuousRecognition()
        await MainActor.run {
            isRecognizing = false
            recognitionState.isMusicRecognitionActive = false
            recognitionState.clearCancelRecognitionHandler()
        }
        await resumePlaybackIfNeeded()
    }

    private func toggleContinuousRecognition() async {
        wasPlayingBeforeRecognition = musicPlayer.isPlaying
        if isContinuousRecognizing {
            continuousStopTask?.cancel()
            continuousStopTask = nil
            isTimedRecognizing = false
            await recognizer.stopContinuousRecognition()
            isContinuousRecognizing = false
            await MainActor.run {
                recognitionState.isMusicRecognitionActive = false
                recognitionState.clearCancelRecognitionHandler()
            }
            await resetContinuousRecognitionCooldown()
            await resumePlaybackIfNeeded()
            return
        }

        isContinuousRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        await MainActor.run {
            recognitionState.isMusicRecognitionActive = true
            recognitionState.shouldResumePlaybackAfterRecognition = true
            recognitionState.cancelRecognition = {
                await toggleContinuousRecognition()
            }
        }
        await resetContinuousRecognitionCooldown()
        do {
            try await recognizer.startContinuousRecognition(for: nil) { result in
                Task { @MainActor in
                    guard shouldProcessContinuousRecognitionResult() else {
                        return
                    }
                    recognitionResult = result
                    addToHistory(from: result)
                }
            }
        } catch {
            errorMessage = "Recognition failed. \(error.localizedDescription)"
            isContinuousRecognizing = false
            await MainActor.run {
                recognitionState.isMusicRecognitionActive = false
                recognitionState.clearCancelRecognitionHandler()
            }
            await resumePlaybackIfNeeded()
        }
    }

    private func startTimedRecognition(duration: TimeInterval) async {
        guard !isContinuousRecognizing else { return }
        wasPlayingBeforeRecognition = musicPlayer.isPlaying
        isTimedRecognizing = true
        isContinuousRecognizing = true
        recognitionResult = nil
        errorMessage = nil
        await MainActor.run {
            recognitionState.isMusicRecognitionActive = true
            recognitionState.shouldResumePlaybackAfterRecognition = true
            recognitionState.cancelRecognition = {
                await toggleContinuousRecognition()
            }
        }
        await resetContinuousRecognitionCooldown()
        continuousStopTask?.cancel()
        continuousStopTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                print("Discover timed recognition sleep failed: \(error)")
            }
            await MainActor.run {
                isContinuousRecognizing = false
                isTimedRecognizing = false
                recognitionState.isMusicRecognitionActive = false
                recognitionState.clearCancelRecognitionHandler()
            }
            await resumePlaybackIfNeeded()
        }
        do {
            try await recognizer.startContinuousRecognition(for: duration) { result in
                Task { @MainActor in
                    guard shouldProcessContinuousRecognitionResult() else {
                        return
                    }
                    recognitionResult = result
                    addToHistory(from: result)
                }
            }
        } catch {
            errorMessage = "Recognition failed. \(error.localizedDescription)"
            isContinuousRecognizing = false
            isTimedRecognizing = false
            await MainActor.run {
                recognitionState.isMusicRecognitionActive = false
                recognitionState.clearCancelRecognitionHandler()
            }
            continuousStopTask?.cancel()
            continuousStopTask = nil
            await resumePlaybackIfNeeded()
        }
    }

    @MainActor
    private func resumePlaybackIfNeeded() async {
        defer {
            recognitionState.shouldResumePlaybackAfterRecognition = true
        }
        let wasPlaying = wasPlayingBeforeRecognition
        wasPlayingBeforeRecognition = false
        guard wasPlaying, recognitionState.shouldResumePlaybackAfterRecognition else { return }
        do {
            try await musicPlayer.unpause()
        } catch {
            print("Failed to unpause music player after recognition: \(error)")
        }
    }

    @MainActor
    private func addToHistory(from result: MusicRecognitionResult) {
        let recognizedDate = result.recognizedAt
        let appleMusicID = result.storefrontId
        let shazamID = result.id

        // Build a predicate that SwiftData supports
        let descriptor: FetchDescriptor<PlayedTrack>
        if let storefrontId = result.storefrontId {
            let capturedStorefrontId = storefrontId
            descriptor = FetchDescriptor(
                predicate: #Predicate { track in
                    track.appleMusicID == capturedStorefrontId
                }
            )
        } else {
            let title = result.title
            let artist = result.artist
            let album = result.album ?? "Unknown Album"
            descriptor = FetchDescriptor(
                predicate: #Predicate { track in
                    track.title == title && track.artist == artist && track.album == album
                }
            )
        }

        do {
            if let existingTrack = try modelContext.fetch(descriptor).first {
                existingTrack.recognizedByShazam = true
                existingTrack.recognizedAt = recognizedDate
                existingTrack.recognizedHistory.append(recognizedDate)
                if existingTrack.appleMusicID == nil, let appleMusicID {
                    existingTrack.appleMusicID = appleMusicID
                }
                if existingTrack.shazamID == nil, let shazamID {
                    existingTrack.shazamID = shazamID
                }
                return
            }
        } catch {
            errorMessage = "Failed to save recognized track."
        }

        let track = PlayedTrack(
            title: result.title,
            artist: result.artist,
            album: result.album ?? "Unknown Album",
            artworkURL: result.artworkUrl,
            previewURL: nil,
            duration: 0,
            appleMusicID: appleMusicID,
            spotifyID: nil,
            tidalID: nil,
            youTubeID: nil,
            shazamID: shazamID,
            playCount: 0,
            playHistory: [],
            recognizedByShazam: true,
            recognizedAt: recognizedDate,
            recognizedHistory: [recognizedDate]
        )
        modelContext.insert(track)
    }

    @MainActor
    private func shouldProcessContinuousRecognitionResult() -> Bool {
        guard !isContinuousRecognitionOnCooldown else {
            return false
        }
        startContinuousRecognitionCooldown()
        return true
    }

    @MainActor
    private func startContinuousRecognitionCooldown() {
        continuousRecognitionCooldownTask?.cancel()
        isContinuousRecognitionOnCooldown = true
        let cooldownNanos = UInt64(continuousRecognitionCooldown * 1_000_000_000)
        continuousRecognitionCooldownTask = Task {
            do {
                try await Task.sleep(nanoseconds: cooldownNanos)
            } catch is CancellationError {
                // fall through to reset state
            } catch {
                print("Discover continuous recognition cooldown failed: \(error)")
            }
            await MainActor.run {
                isContinuousRecognitionOnCooldown = false
                continuousRecognitionCooldownTask = nil
            }
        }
    }

    @MainActor
    private func resetContinuousRecognitionCooldown() {
        continuousRecognitionCooldownTask?.cancel()
        continuousRecognitionCooldownTask = nil
        isContinuousRecognitionOnCooldown = false
    }
}

#Preview {
    DiscoverView()
        .environmentObject(RecognitionListeningState())
}
