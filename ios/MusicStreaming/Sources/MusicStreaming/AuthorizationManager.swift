//
//  AuthorizationManager.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import MusicKit
import Combine

public enum StreamingProvider: String {
	case appleMusic
	case spotify
	case tidal
	case none
}

@MainActor
public class AuthorizationManager: ObservableObject {
	@Published public var isAuthorized: Bool = false
	@Published public var currentProvider: StreamingProvider = .none
	
	public init() {
		Task {
			await checkAuthorization()
		}
	}
	
	public func checkAuthorization() async {
		// Check Apple Music
		let status = MusicAuthorization.currentStatus
		if status == .authorized {
			isAuthorized = true
			currentProvider = .appleMusic
		} else {
			// Here you would check for stored tokens for Spotify/Tidal
			// For now, we assume if Apple Music isn't authorized, nothing is.
			isAuthorized = false
			currentProvider = .none
		}
	}
	
	public func authorizeAppleMusic() async {
		let status = await MusicAuthorization.request()
		if status == .authorized {
			isAuthorized = true
			currentProvider = .appleMusic
		}
	}
}
