//
//  AuthorizationManager.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import MusicKit
import Combine
import Auth

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
	
	private var tidalClientId: String = "P7AYqSKY9Slcppll"
	private var tidalClientSecret: String = "Wnb5SDn6xV2gBz6CRWN3ipJNQ0QcGv3Piudmy8m1lcc="

	public init() {
		let config = AuthConfig(clientId: tidalClientId, credentialsKey: tidalClientSecret)
		TidalAuth.shared.config(config: config)
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
		} else if TidalAuth.shared.isUserLoggedIn {
            isAuthorized = true
            currentProvider = .tidal
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

	public func authorizeTidal() async throws {
		isAuthorized = true
		currentProvider = .tidal
	}
}
