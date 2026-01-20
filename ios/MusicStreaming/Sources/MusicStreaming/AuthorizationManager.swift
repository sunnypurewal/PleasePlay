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
	
	private var tidalClientId: String? = "P7AYqSKY9Slcppll" // Replace with actual ID
	private var tidalClientSecret: String? = "Wnb5SDn6xV2gBz6CRWN3ipJNQ0QcGv3Piudmy8m1lcc=" // Replace with actual Secret

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
		} else if tidalClientId != nil && tidalClientSecret != nil {
			// In a real app, you would check for a stored Tidal token
			// For now, we'll assume if credentials are provided, we can "authorize"
			// by attempting to get a token silently or checking for a stored one.
			// This part will require the Tidal Auth SDK.
            // FIXED: Do not auto-authorize just because credentials exist.
			// isAuthorized = true // Placeholder
			// currentProvider = .tidal
            isAuthorized = false
            currentProvider = .none
		} else {
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

	public func authorizeTidal(clientId: String, clientSecret: String) async {
		self.tidalClientId = clientId
		self.tidalClientSecret = clientSecret
		// In a real app, you would now trigger the Tidal login flow
		// and on success, store the tokens securely.
		// For now, we'll just update the authorization status.
		isAuthorized = true
		currentProvider = .tidal
	}
}
