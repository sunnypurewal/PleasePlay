//
//  Predictor.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-17.
//

import Foundation
import CoreML
import Tokenizers

@available(iOS 26.0, *)
public actor Predictor {
	private var model: MusicNER?
	private var isLoading = false
    
    public init() {}
	
	public func loadModel() async throws {
		guard model == nil else { return }
		isLoading = true
		self.model = try MusicNER()
		isLoading = false
		print("MusicNER model loaded successfully")
	}
	
	public func predictEntities(from text: String) async throws -> [String: Any] {
		if !isLoading {
			if model == nil {
				try await loadModel()
			}
		} else {
			while isLoading {
				try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
			}
		}
		guard let model else {
			throw NSError(domain: "Predictor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
		}
		// Proceed with entity prediction using the model
		return try await runNER(on: text, model: model)
	}

	private func runNER(on text: String, model: MusicNER) async throws -> [String: Any] {
		print("Loading tokenizer and encoding text")
		let tokenizer = try await loadBertTokenizer(fromVocabFile: "vocab", withExtension: "txt")
		let tokens = tokenizer.encode(text: text) // [Int]
		
		// Prepare inputs
		// Note: Model expects fixed size 128 based on current invocation, or we can try dynamic if the model supports it.
		// The Swift wrapper likely expects [1, 128] if we use the generated class with fixed constraints, 
		// but since we exported with RangeDim, we could technically pass exact shape. 
		// For safety and matching previous code, we stick to 128 or just use token count if possible.
		// Let's stick to 128 but zero-init to be safe.
		
		let seqLen = 128
		let input_ids = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)
		let attention_mask = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)
		
		// Initialize with zeros (MLMultiArray is not guaranteed to be zeroed)
		for i in 0..<seqLen {
			input_ids[i] = 0
			attention_mask[i] = 0
		}
		
		// Fill data
		let filledCount = min(tokens.count, seqLen)
		for i in 0..<filledCount {
			input_ids[i] = NSNumber(value: tokens[i])
			attention_mask[i] = 1
		}
		
		print("Input prepared (tokens: \(filledCount)), making prediction")
		let input = MusicNERInput(input_ids: input_ids, attention_mask: attention_mask)
		let output = try await model.prediction(input: input)
		print("Prediction made")
		
		// Output processing
		// Look for "logits"
		guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
			print("Error: No 'logits' feature in output")
			return [:]
		}
		
		// logits shape: [1, 128, 5] (Batch, Seq, Labels)
		// We only care about the first 'filledCount' tokens
		
		var extractedArtists: [String] = []
		var extractedWoAs: [String] = []
		
		var currentTokens: [Int] = []
		var currentLabelType: String? = nil // "Artist", "WoA"
		
		// Label Map: 0: "O", 1: "B-Artist", 2: "I-Artist", 3: "B-WoA", 4: "I-WoA"
		
		for i in 0..<filledCount {
			// Find max score index for this token
			var maxIdx = 0
			var maxVal: Float = -Float.greatestFiniteMagnitude
			
			for j in 0..<5 {
				let index: [NSNumber] = [0, NSNumber(value: i), NSNumber(value: j)]
				let val = logits[index].floatValue
				if val > maxVal {
					maxVal = val
					maxIdx = j
				}
			}
			
			let label = maxIdx
			// 0=O, 1=B-Artist, 2=I-Artist, 3=B-WoA, 4=I-WoA
			
			if label == 1 || label == 3 { // B-Tag
				// Save previous if exists
				if let type = currentLabelType, !currentTokens.isEmpty {
					let str = tokenizer.decode(tokens: currentTokens)
					if type == "Artist" { extractedArtists.append(str) }
					else if type == "WoA" { extractedWoAs.append(str) }
				}
				
				// Start new
				currentTokens = [tokens[i]]
				currentLabelType = (label == 1) ? "Artist" : "WoA"
				
			} else if label == 2 || label == 4 { // I-Tag
				let expectedType = (label == 2) ? "Artist" : "WoA"
				if currentLabelType == expectedType {
					// Continue entity
					currentTokens.append(tokens[i])
				} else {
					// Mismatch or start with I (invalid).
					// Save previous and reset.
					if let type = currentLabelType, !currentTokens.isEmpty {
						let str = tokenizer.decode(tokens: currentTokens)
						if type == "Artist" { extractedArtists.append(str) }
						else if type == "WoA" { extractedWoAs.append(str) }
					}
					currentTokens = []
					currentLabelType = nil
				}
			} else { // O
				// Save previous if exists
				if let type = currentLabelType, !currentTokens.isEmpty {
					let str = tokenizer.decode(tokens: currentTokens)
					if type == "Artist" { extractedArtists.append(str) }
					else if type == "WoA" { extractedWoAs.append(str) }
				}
				currentTokens = []
				currentLabelType = nil
			}
		}
		
		// Flush last
		if let type = currentLabelType, !currentTokens.isEmpty {
			let str = tokenizer.decode(tokens: currentTokens)
			if type == "Artist" { extractedArtists.append(str) }
			else if type == "WoA" { extractedWoAs.append(str) }
		}
		
		print("Artists: \(extractedArtists)")
		print("WoAs: \(extractedWoAs)")
		
		return [
			"Artists": extractedArtists,
			"WoAs": extractedWoAs
		]
	}
	
	enum TokenizerError: Error {
		case fileNotFound
		case fileReadError(Error)
		case initializationError(String)
	}
	
	func loadBertTokenizer(fromVocabFile vocabFileName: String, withExtension ext: String) async throws -> any Tokenizer {
		return try await AutoTokenizer.from(pretrained: "distilbert/distilbert-base-cased-distilled-squad")
	}
}