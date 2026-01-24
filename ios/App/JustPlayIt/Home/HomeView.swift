//
//  HomeView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import Combine
import AVFoundation
import CoreML
import SwiftData
import Tokenizers
import MusicStreaming
import MusicAI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PlayedTrack.addedAt, order: .reverse) private var playedTracks: [PlayedTrack]
    @Environment(MusicPlayer.self) var musicPlayer
    @EnvironmentObject private var recognitionState: RecognitionListeningState
    @State private var microphonePermissionGranted = false
    @AppStorage("isAutomaticListeningEnabled") private var isAutomaticListeningEnabled = true
    @State private var predictor = Predictor()
    @State private var searchResults: [Track] = []
    @State private var suggestions: [Track] = []
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
        ScrollView {
            VStack(spacing: 24) {
                // Microphone Permission Banner
                if !microphonePermissionGranted {
                    MicrophonePermissionView(onRequestAccess: requestMicrophoneAccess)
                }
                
                if !isPlayingDebounced && !musicPlayer.isSeeking {
                    MicrophoneStatusView(
                        isListening: recognitionState.isMicrophoneStreaming,
                        isAutomaticListeningEnabled: $isAutomaticListeningEnabled,
                        toggleListening: { await toggleMicrophoneListening() },
                        onAutomaticListeningChanged: { isEnabled in await handleAutomaticListeningChange(isEnabled) }
                    )
                } else if !isSearching {
                    nowPlayingHighlight
                }
                
                // Content for Empty State vs Now Playing
                if isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 32) {
                        if musicPlayer.isPlaying || musicPlayer.isSeeking {
                            if !suggestions.isEmpty {
                                suggestionsSection
                            }
                        }
                        
                        if (playedTracks.isEmpty && suggestions.isEmpty && !isPlayingDebounced) || (!musicPlayer.isPlaying && !musicPlayer.isSeeking) {
                            VStack(spacing: 20) {
                                Image(systemName: "music.note.house")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("Welcome to Sonnio")
                                    .font(.title2)
                                    .bold()
                                Text("Try saying \"Please play \(songVoiceCommandSuggestion)\" to get started.")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 40)
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .onAppear {
            schedulePlaybackStateDebounce(isPlaying: musicPlayer.isPlaying)
            checkMicrophonePermission(shouldStartListening: !hasAppeared)
            hasAppeared = true
            startInitialListeningIfNeeded()
            refreshVoiceCommandSuggestion()
            refreshSuggestions()
        }
        .onChange(of: playedTracks) { _, _ in
            refreshVoiceCommandSuggestion()
        }
        .onChange(of: musicPlayer.currentTrack?.serviceIDs) { _, _ in
            refreshSuggestions()
        }
        .onChange(of: recognitionState.speechTranscriber.finalizedTranscript) { old, new in
            let transcript = String(new.characters)
            guard !transcript.isEmpty else { return }
            guard let triggerRange = transcript.range(of: "please play", options: .caseInsensitive) else {
                recognitionState.speechTranscriber.resetTranscripts()
                return
            }
			let text = String(transcript[triggerRange.lowerBound...])
            Task {
                do {
                    let output = try await predictor.predictEntities(from: text)

                    recognitionState.speechTranscriber.resetTranscripts()
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
        }
        .onChange(of: recognitionState.isMusicRecognitionActive) { _, isActive in
            // Handled by AutoListenCoordinator
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    // This might still be useful to ensure we start if we were suspended
                    await resumeAutomaticListeningIfAllowed(reason: "app foregrounded")
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
        if shouldStartListening {
            Task {
                await resumeAutomaticListeningIfAllowed(reason: "microphone permission check")
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

    @MainActor
    private func resumeAutomaticListeningIfAllowed(reason: String) async {
        guard isAutomaticListeningEnabled,
              microphonePermissionGranted,
              !musicPlayer.isPlaying,
              recognitionState.shouldAutomaticallyListenForCommands,
              !recognitionState.isMusicRecognitionActive else { return }

        do {
            try await startMicrophoneStreaming()
        } catch {
            print("Failed to resume microphone streaming (\(reason)): \(error)")
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
        try await recognitionState.startMicrophoneStreaming()
    }

    @MainActor
    private func stopMicrophoneStreaming() async {
        await recognitionState.stopMicrophoneStreaming()
    }

    @MainActor
    private func toggleMicrophoneListening() async {
        guard !recognitionState.isMusicRecognitionActive else { return }
        if recognitionState.isMicrophoneStreaming {
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

    private var nowPlayingHighlight: some View {
        Group {
            if let currentTrack = musicPlayer.currentTrack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Now Playing")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        if let url = currentTrack.artworkURL {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            Image(systemName: "music.note")
                                .font(.title)
                                .frame(width: 80, height: 80)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentTrack.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(currentTrack.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(suggestionsTitle)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(suggestions, id: \.serviceIDs) { track in
                        Button(action: {
                            Task {
                                await cancelRecognitionBeforePlayback()
                                do {
                                    try await musicPlayer.play(track: track)
                                } catch {
                                    print("Failed to play suggested track: \(error)")
                                }
                                await MainActor.run {
                                    saveTrack(track)
                                }
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let url = track.artworkURL {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 140, height: 140)
                                    .cornerRadius(8)
                                    .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 140, height: 140)
                                        .cornerRadius(8)
                                        .overlay(Image(systemName: "music.note").font(.largeTitle))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var suggestionsTitle: String {
        if let current = musicPlayer.currentTrack {
            return "More by \(current.artist)"
        }
        return "You Might Like"
    }

    private func refreshSuggestions() {
        guard let current = musicPlayer.currentTrack else {
            // Maybe suggest based on top played artist?
            if let topArtist = playedTracks.first?.artist {
                 fetchSuggestions(for: topArtist)
            }
            return
        }
        fetchSuggestions(for: current.artist)
    }

    private func fetchSuggestions(for artist: String) {
        Task {
            do {
                let results = try await musicPlayer.getTopSongs(for: artist)
                await MainActor.run {
                    // Filter out current track if possible
                    self.suggestions = results.filter { track in
                        if let current = musicPlayer.currentTrack {
                            return track.title != current.title
                        }
                        return true
                    }
                }
            } catch {
                print("Failed to fetch suggestions: \(error)")
            }
        }
    }

}

#Preview {
    HomeView()
        .environment(MusicPlayer())
        .environmentObject(RecognitionListeningState())
}
