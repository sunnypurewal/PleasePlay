//
//  Unauthenticated.swift
//  JustPlayIt
//
//  Created by Gemini on 2026-xx-xx.
//

import Foundation
import MusicKit

public final class Unauthenticated {
    public init() {}

    public func developerToken() async throws -> String {
		let token = try await DefaultMusicTokenProvider().developerToken(options: .ignoreCache)
		return token
    }
}
