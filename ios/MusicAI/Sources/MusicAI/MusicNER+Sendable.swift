//
//  MusicNER+Sendable.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-20.
//

import Foundation

// MusicNER is a generated CoreML class, so we mark it unchecked Sendable
// assuming we are managing concurrency safely (e.g. inside an actor)
extension MusicNER: @unchecked Sendable {}
extension MusicNERInput: @unchecked Sendable {}
extension MusicNEROutput: @unchecked Sendable {}
