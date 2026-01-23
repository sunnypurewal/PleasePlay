//
//  HomeView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import AVFoundation
import CoreML
import SwiftData
import Tokenizers
import MusicStreaming
import MusicAI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var playedTracks: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @EnvironmentObject private var recognitionState: RecognitionListeningState
    @State private var microphonePermissionGranted = false
    @AppStorage("isAutomaticListeningEnabled") private var isAutomaticListeningEnabled = false
    private let input = MicrophoneInput()
    @State private var speechTranscriber = SpokenWordTranscriber()
    @State private var predictor = Predictor()
    @State private var isMicrophoneStreaming = false
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var hasAppeared = false
    @State private var hasStartedInitialListening = false
    @State private var songVoiceCommandSuggestion = "Blackbird by The Beatles"
    @State private var artistVoiceCommandSuggestion = "The Beatles"
    @State private var recognizedArtist = ""
    @State private var recognizedTitle = ""
    @State private var isPlayingDebounced = false
    @State private var playbackDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack {
            // Microphone Permission Banner
            if !microphonePermissionGranted {
                MicrophonePermissionView(onRequestAccess: requestMicrophoneAccess)
            }
            
            if !isPlayingDebounced && !musicPlayer.isSeeking {
                MicrophoneStatusView(
                    isListening: isMicrophoneStreaming,
                    isAutomaticListeningEnabled: $isAutomaticListeningEnabled,
                    toggleListening: { await toggleMicrophoneListening() },
                    onAutomaticListeningChanged: { isEnabled in await handleAutomaticListeningChange(isEnabled) }
                )
                if isMicrophoneStreaming {
                    VStack(spacing: 12) {
                        Text("All commands start with \"Please play\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        VStack(spacing: 4) {
                            Text("\"**Please play** \(songVoiceCommandSuggestion)\"")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            Text("\"**Please play** \(artistVoiceCommandSuggestion)\"")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onAppear {
                        refreshVoiceCommandSuggestion()
                    }
				}
				Spacer()
            }
            
            Spacer()
            
            // Content for Empty State vs Now Playing
            if isSearching {
                ProgressView("Searching...")
                Spacer()
            } else if !searchResults.isEmpty {
                VStack(alignment: .leading) {
                    Text(resultsListTitle)
                        .font(.headline)
                        .padding(.horizontal)
                    
                            List(searchResults, id: \.serviceIDs) { track in
                                Button(action: {
                                    Task {
                                        await cancelRecognitionBeforePlayback()
                                        do {
                                            try await musicPlayer.play(track: track)
                                        } catch {
                                            print("Failed to play selected track: \(error)")
                                        }
                                        await MainActor.run {
                                            saveTrack(track)
                                        }
                                    }
                                }) {
                            HStack {
                                if let url = track.artworkURL {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                                } else {
                                    Image(systemName: "music.note")
                                        .frame(width: 50, height: 50)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.headline)
                                    Text(track.artist)
                                        .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if musicPlayer.currentTrack?.serviceIDs == track.serviceIDs {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onAppear {
            schedulePlaybackStateDebounce(isPlaying: musicPlayer.isPlaying)
            checkMicrophonePermission(shouldStartListening: !hasAppeared)
            hasAppeared = true
            startInitialListeningIfNeeded()
            refreshVoiceCommandSuggestion()
        }
        .onChange(of: playedTracks) { _, _ in
            refreshVoiceCommandSuggestion()
        }
        .onChange(of: speechTranscriber.finalizedTranscript) { old, new in
            let transcript = String(new.characters)
            guard !transcript.isEmpty else { return }
            guard let triggerRange = transcript.range(of: "please play", options: .caseInsensitive) else {
                speechTranscriber.resetTranscripts()
                return
            }
            let text = String(transcript[triggerRange.lowerBound...])
            Task {
                do {
                    let output = try await predictor.predictEntities(from: text)

                    speechTranscriber.resetTranscripts()
                    print(output)

                    let artists = output["Artists"] as? [String] ?? []
                    let woas = output["WoAs"] as? [String] ?? []

                    let artist = artists.first ?? ""
                    let title = woas.first ?? ""

                    let query = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
                    let searchQuery = query.isEmpty ? text : query
                    
                    await MainActor.run {
                        self.recognizedArtist = artist
                        self.recognizedTitle = title
                    }

                    if !searchQuery.isEmpty {
                        let hasEntity = !(artist.isEmpty && title.isEmpty)
                        if !hasEntity {
                            await MainActor.run {
                                self.isSearching = false
                            }
                            return
                        }
                        isSearching = true
                        // Perform search
                    async let searchTask = musicPlayer.search(query: searchQuery)

                    var playedTrack: Track?
                    if !artist.isEmpty || !title.isEmpty {
                        await cancelRecognitionBeforePlayback()
                        do {
                            playedTrack = try await musicPlayer.play(artist: artist, song: title)
                        } catch {
                            print("Failed to play predicted track: \(error)")
                        }
                    }

                    var results: [Track] = []
                    do {
                        results = try await searchTask
                    } catch {
                        print("Failed to fetch search results: \(error)")
                    }

                    await MainActor.run {
                        if let track = playedTrack {
                            saveTrack(track)
                        }
                        let allResults = results
                            if title.isEmpty && !artist.isEmpty {
                                self.searchResults = allResults
                            } else {
                                self.searchResults = allResults.filter { track in
                                    allResults.contains { $0.title.lowercased() == track.title.lowercased() && $0.artist.lowercased() != track.artist.lowercased() }
                                }
                            }
                            self.isSearching = false
                        }
                    }
                } catch {
                    print("Prediction error: \(error)")
                    isSearching = false
                }
            }
        }
        .onChange(of: musicPlayer.isPlaying) { _, isPlaying in
            schedulePlaybackStateDebounce(isPlaying: isPlaying)
            Task {
                if isPlaying {
                    await stopMicrophoneStreaming()
                } else if isAutomaticListeningEnabled && recognitionState.shouldAutomaticallyListenForCommands && !recognitionState.isMusicRecognitionActive {
                    do {
                        try await startMicrophoneStreaming()
                    } catch {
                        print("Failed to resume microphone streaming: \(error)")
                    }
                }
            }
        }
        .onChange(of: recognitionState.isMusicRecognitionActive) { _, isActive in
            Task {
                if isActive {
                    await stopMicrophoneStreaming()
                } else if isAutomaticListeningEnabled && recognitionState.shouldAutomaticallyListenForCommands && !musicPlayer.isPlaying && microphonePermissionGranted {
                    do {
                        try await startMicrophoneStreaming()
                    } catch {
                        print("Failed to resume microphone streaming after recognition: \(error)")
                    }
                }
            }
        }
        .task {
            do {
                try await predictor.loadModel()
            } catch {
                print("Failed to load model: \(error)")
            }
        }
    }
    
    private var resultsListTitle: String {
        if !recognizedTitle.isEmpty && !recognizedArtist.isEmpty {
            return "\(recognizedTitle) by \(recognizedArtist)"
        }
        if !recognizedArtist.isEmpty {
            return recognizedArtist
        }
        return "Search Results"
    }

    @MainActor
    private func schedulePlaybackStateDebounce(isPlaying: Bool) {
        playbackDebounceTask?.cancel()
        if isPlaying {
            isPlayingDebounced = true
            playbackDebounceTask = nil
            return
        }

        playbackDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                print("Playback debounce sleep failed: \(error)")
            }
            if Task.isCancelled { return }
            await MainActor.run {
                playbackDebounceTask = nil
                if !musicPlayer.isPlaying {
                    isPlayingDebounced = false
                }
            }
        }
    }
    
    private func checkMicrophonePermission(shouldStartListening: Bool) {
        let isGranted: Bool
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
                case .granted:
                    isGranted = true
                case .denied, .undetermined:
                    isGranted = false
                @unknown default:
                    isGranted = false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
                case .granted:
                    isGranted = true
                case .denied, .undetermined:
                    isGranted = false
                @unknown default:
                    isGranted = false
            }
        }
        
        microphonePermissionGranted = isGranted
        if shouldStartListening && isGranted && !musicPlayer.isPlaying && isAutomaticListeningEnabled && recognitionState.shouldAutomaticallyListenForCommands && !recognitionState.isMusicRecognitionActive {
            Task {
                do {
                    try await startMicrophoneStreaming()
                } catch {
                    print("Failed to start microphone streaming: \(error)")
                }
            }
        }
    }
    
    private func requestMicrophoneAccess() {
        let completion: (Bool) -> Void = { granted in
            DispatchQueue.main.async {
                self.handleMicrophonePermissionResult(granted: granted)
            }
        }

		AVAudioApplication.requestRecordPermission(completionHandler: completion)
    }

    private func handleMicrophonePermissionResult(granted: Bool) {
        let wasPreviouslyGranted = microphonePermissionGranted
        microphonePermissionGranted = granted
        guard granted && !wasPreviouslyGranted else { return }
        startInitialListeningIfNeeded()
    }

    private func startInitialListeningIfNeeded() {
        guard !hasStartedInitialListening,
              microphonePermissionGranted,
              !musicPlayer.isPlaying,
              !recognitionState.isMusicRecognitionActive else { return }

        hasStartedInitialListening = true
        Task {
            do {
                try await startMicrophoneStreaming()
            } catch {
                print("Failed to start initial streaming: \(error)")
            }
        }
    }

    private func cancelRecognitionBeforePlayback() async {
        guard recognitionState.isMusicRecognitionActive else { return }
        await recognitionState.requestCancelRecognition(skipResume: true)
    }
    
    private func saveTrack(_ track: Track) {
        let title = track.title
        let artist = track.artist
        
        let descriptor = FetchDescriptor<PlayedTrack>(
            predicate: #Predicate { $0.title == title && $0.artist == artist }
        )
        
        do {
            let existingTracks = try modelContext.fetch(descriptor)
            if let existingTrack = existingTracks.first {
                existingTrack.playCount += 1
                existingTrack.playHistory.append(Date())
                existingTrack.lastPlayedAt = Date()
            } else {
                let playedTrack = PlayedTrack(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    artworkURL: track.artworkURL,
                    previewURL: track.previewURL,
                    duration: track.duration,
                    appleMusicID: track.serviceIDs.appleMusic,
                    spotifyID: track.serviceIDs.spotify,
                    tidalID: track.serviceIDs.tidal,
                    youTubeID: track.serviceIDs.youtube
                )
                modelContext.insert(playedTrack)
            }
        } catch {
            print("Failed to save track: \(error)")
        }
    }

    private func refreshVoiceCommandSuggestion() {
        if let track = playedTracks.randomElement(), !track.title.isEmpty, !track.artist.isEmpty {
            songVoiceCommandSuggestion = "\(track.title) by \(track.artist)"
        } else {
            songVoiceCommandSuggestion = "Blackbird by The Beatles"
        }

        let artistOptions = playedTracks
            .map { $0.artist }
            .filter { !$0.isEmpty }
        artistVoiceCommandSuggestion = artistOptions.randomElement() ?? "The Beatles"
    }

    @MainActor
    private func startMicrophoneStreaming() async throws {
        guard !isMicrophoneStreaming else { return }
        do {
            try await speechTranscriber.setUpTranscriber()
            let stream = try await input.startStreaming()
            speechTranscriber.startTranscribing(from: stream)
        } catch {
            await input.stopStreaming()
            throw error
        }
        isMicrophoneStreaming = true
    }

    @MainActor
    private func stopMicrophoneStreaming() async {
        guard isMicrophoneStreaming else { return }
        await input.stopStreaming()
        do {
            try await speechTranscriber.finishTranscribing()
        } catch {
            print("Failed to finish transcribing: \(error)")
        }
        isMicrophoneStreaming = false
    }

    @MainActor
    private func toggleMicrophoneListening() async {
        guard !recognitionState.isMusicRecognitionActive else { return }
        if isMicrophoneStreaming {
            await stopMicrophoneStreaming()
        } else if microphonePermissionGranted {
            do {
                try await startMicrophoneStreaming()
            } catch {
                print("Failed to start microphone streaming: \(error)")
            }
        }
    }

    @MainActor
    private func handleAutomaticListeningChange(_ isEnabled: Bool) async {
        if recognitionState.isMusicRecognitionActive {
            return
        }

        if isEnabled {
            recognitionState.enableAutomaticCommandListening()
            guard microphonePermissionGranted else { return }
            do {
                try await startMicrophoneStreaming()
            } catch {
                print("Failed to start microphone streaming after enabling auto listen: \(error)")
            }
        } else {
            recognitionState.disableAutomaticCommandListening()
            await stopMicrophoneStreaming()
        }
    }
}

#Preview {
    HomeView()
        .environment(MusicPlayer())
        .environmentObject(RecognitionListeningState())
}
