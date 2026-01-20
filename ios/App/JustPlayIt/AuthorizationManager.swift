//
//  AuthorizationManager.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import MusicKit
import Combine

enum StreamingProvider: String {
	case appleMusic
	case spotify
	case tidal
	case none
}

@MainActor
class AuthorizationManager: ObservableObject {
	@Published var isAuthorized: Bool = false
	@Published var currentProvider: StreamingProvider = .none
	
	init() {
		Task {
			await checkAuthorization()
		}
	}
	
	func checkAuthorization() async {
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
	
	func authorizeAppleMusic() async {
		let status = await MusicAuthorization.request()
		if status == .authorized {
			isAuthorized = true
			currentProvider = .appleMusic
		}
	}
}
