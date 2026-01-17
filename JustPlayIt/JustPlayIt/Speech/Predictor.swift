//
//  Predictor.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-17.
//

import Foundation
import CoreML
import Tokenizers

actor Predictor {
	private var model: MusicNER?
	
	private func loadModel() async throws {
		self.model = try await MusicNER()
		print("MusicNER model loaded successfully")
	}
	
	func predictEntities(from text: String) async throws -> [String: Any] {
		if model == nil {
			try await loadModel()
		}
		guard let model else {
			throw NSError(domain: "Predictor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
		}
		// Proceed with entity prediction using the model
		return try await runNER(on: text, model: model)
	}

	private func runNER(on text: String, model: MusicNER) async throws -> [String: Any] {
		print("Loading model")
		print("Model loaded, running prediction")
		let tokenizer = try await loadBertTokenizer(fromVocabFile: "vocab", withExtension: "txt")
		let tokens = tokenizer.encode(text: text)
		print(tokens)
		print("Text tokenized: \(tokens)")
		print("Input prepared, making prediction")
		let input = await MusicNERInput(input_ids: try MLMultiArray(tokens), attention_mask: try MLMultiArray(shape: [1,128], dataType: .float32))
		// TODO: Figure out why coreml model not loading
		let output = try await model.prediction(input: input)
		print("Prediction made")
		print(output)
		// Assuming the output key is "output" and it's a string
		if let artists = await output.featureValue(for: "Artists")?.stringValue {
			print("Artists recognized: \(artists)")
		}
		if let songs = await output.featureValue(for: "Songs/Albums")?.stringValue {
			print("Songs/Albums recognized: \(songs)")
		}
		if let woa = await output.featureValue(for: "WoA")?.stringValue {
			print("WoA recognized: \(woa)")
		}
		return [:]
	}
	
	enum TokenizerError: Error {
		case fileNotFound
		case fileReadError(Error)
		case initializationError(String)
	}
	
	func loadBertTokenizer(fromVocabFile vocabFileName: String, withExtension ext: String) async throws -> any Tokenizer {
		return try await AutoTokenizer.from(pretrained: "bert-base-uncased")
	}
}
