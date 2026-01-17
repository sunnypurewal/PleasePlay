//
//  PlayerView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import AVFoundation
import CoreML
import Tokenizers

struct PlayerView: View {
	@State private var microphonePermissionGranted = false
	@State private var alreadyPlayedSongs: [String] = [] // Mock data for now
	@State private var nowPlayingSong: String? = nil
	@State var recorder: Recorder
	@State var speechTranscriber: SpokenWordTranscriber
	@State private var mlModel: MusicNER?
	
	init() {
		let transcriber = SpokenWordTranscriber()
		recorder = Recorder(transcriber: transcriber)
		speechTranscriber = transcriber
		
		do {
			mlModel = try MusicNER()
			print("ML model loaded \(mlModel)")
		} catch {
			print("Failed to load ML model: \(error)")
		}
	}
	
	var body: some View {
		NavigationStack {
			VStack {
				// Microphone Permission Banner
				if !microphonePermissionGranted {
					MicrophonePermissionView(onRequestAccess: requestMicrophoneAccess)
				}
				
				// Already Played Section
				AlreadyPlayedView(songs: alreadyPlayedSongs)
				
				Spacer()
				
				// Content for Empty State vs Now Playing
				if let currentSong = nowPlayingSong {
					NowPlayingView(currentSong: currentSong)
				} else {
					PlayerEmptyStateView(transcript: speechTranscriber.finalizedTranscript)
				}
			}
			.navigationTitle("Player")
			.onAppear {
				checkMicrophonePermission()
			}
			.onChange(of: speechTranscriber.finalizedTranscript) { old, new in
				let text = String(new.characters)
				if !text.isEmpty {
					Task { await runNER(on: text) }
				}
			}
		}
	}
	
	private func checkMicrophonePermission() {
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
		if isGranted {
			Task { try await recorder.record() }
		}
	}
	
	private func requestMicrophoneAccess() {
		if #available(iOS 17.0, *) {
			AVAudioApplication.requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
				}
			}
		} else {
			AVAudioSession.sharedInstance().requestRecordPermission { granted in
				DispatchQueue.main.async {
					self.microphonePermissionGranted = granted
				}
			}
		}
	}
	
	private func runNER(on text: String) async {
		print("Loading model")
		print("Model loaded, running prediction")
		do {
			let tokenizer = try loadBertTokenizer(fromVocabFile: "vocab", withExtension: "txt")
			let words = text.split(separator: " ").map { String($0) }
			let tokens = words.flatMap { tokenizer.tokenize(text: $0) }.compactMap { tokenizer.convertTokenToId($0) }
			print(tokens)
			print("Text tokenized: \(tokens)")
			print("Input prepared, making prediction")
			let input = MusicNERInput(input_ids: try MLMultiArray(tokens), attention_mask: try MLMultiArray(shape: [1,128], dataType: .float32))
			guard let model = mlModel else { return }
			let output = try await model.prediction(input: input)
			print("Prediction made")
			print(output)
			// Assuming the output key is "output" and it's a string
			if let artists = output.featureValue(for: "Artists")?.stringValue {
				print("Artists recognized: \(artists)")
			}
			if let songs = output.featureValue(for: "Songs/Albums")?.stringValue {
				print("Songs/Albums recognized: \(songs)")
			}
			if let woa = output.featureValue(for: "WoA")?.stringValue {
				print("WoA recognized: \(woa)")
			}
		} catch {
			print("NER prediction failed: \(error)")
		}
	}
	
	enum TokenizerError: Error {
		case fileNotFound
		case fileReadError(Error)
		case initializationError(String)
	}
	
	func loadBertTokenizer(fromVocabFile vocabFileName: String, withExtension ext: String) throws -> BertTokenizer {
		// 1. Locate the vocab.txt file in the app bundle
		guard let url = Bundle.main.url(forResource: vocabFileName, withExtension: ext) else {
			throw TokenizerError.fileNotFound
		}
		
		// 2. Read the file content into a String
		let vocabTxt: String
		do {
			vocabTxt = try String(contentsOf: url, encoding: .utf8)
		} catch {
			throw TokenizerError.fileReadError(error)
		}
		
		// 3. Parse the lines into an array of tokens
		let tokens = vocabTxt.split(separator: "\n").map { String($0) }
		var vocab: [String: Int] = [:]
		
		// 4. Create the token-to-ID mapping
		for (i, token) in tokens.enumerated() {
			vocab[token] = i
		}
		
		// 5. Initialize the BertTokenizer with the vocabulary
		// The swift-transformers library handles the BasicTokenizer and WordpieceTokenizer internally
		// when initialized correctly.
		// The specific initializer may vary slightly depending on the exact version of the library.
		// A common approach involves creating the necessary configuration and data objects.
		
		// For a simple initialization, the documentation points to an init with a vocab dictionary
		// as shown in some source examples.
		
		// The exact method may involve using the convenience initializer if other config files (like
		// tokenizer_config.json) are present, or a direct init with the vocab map.
		
		// A general approach using available initializers might look like this (refer to official docs for precise init):
		// return BertTokenizer(vocab: vocab, ... other parameters like doLowerCase, etc.)
		
		// An alternative method from the library source example:
		return BertTokenizer(vocab: vocab, merges: nil) // Assuming a simplified initializer exists or using the internal class implementation
	}
}

#Preview {
	PlayerView()
}
