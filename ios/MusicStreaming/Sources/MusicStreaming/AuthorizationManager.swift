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
import AuthenticationServices

public enum StreamingProvider: String, Codable {
	case appleMusic
	case spotify
	case tidal
	case none
}

@MainActor
public class AuthorizationManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published public var isAuthorized: Bool = false
    @Published public var currentProvider: StreamingProvider = .none

    private var tidalClientId: String = "P7AYqSKY9Slcppll" // Replace with actual ID
    private var tidalClientSecret: String = "Wnb5SDn6xV2gBz6CRWN3ipJNQ0QcGv3Piudmy8m1lcc=" // Replace with actual Secret
    private let musicPlayer: MusicPlayer

	public init(musicPlayer: MusicPlayer) {
        self.musicPlayer = musicPlayer
        super.init()
		
		let config = AuthConfig(
			clientId: tidalClientId,
			clientSecret: tidalClientSecret,
			credentialsKey: "auth-storage", // Key for storing credentials in Keychain
			scopes: [] // Example scopes
		)
		TidalAuth.shared.config(config: config)
        Task {
            await checkAuthorization()
        }
    }

    public func checkAuthorization() async {
        // Check for stored provider and credentials
        // For now, default to checking Apple Music
        let status = MusicAuthorization.currentStatus
        if status == .authorized {
            self.isAuthorized = true
            self.currentProvider = .appleMusic
            self.musicPlayer.setProvider(AppleMusic())
        } else {
            // In a real app, check for stored Tidal/Spotify tokens
            self.isAuthorized = false
            self.currentProvider = .none
        }
    }

    public func authorizeAppleMusic() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            self.isAuthorized = true
            self.currentProvider = .appleMusic
            self.musicPlayer.setProvider(AppleMusic())
        }
    }

    public func authorizeTidal() async throws {
		let redirectURI = URL(string: "justplayit://tidalauthorization")!

        let loginConfig = LoginConfig()
        guard let loginUrl = TidalAuth.shared.initializeLogin(redirectUri: redirectURI.absoluteString, loginConfig: loginConfig) else {
            return
        }

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: loginUrl, callbackURLScheme: redirectURI.scheme) { callbackURL, error in
                if let error = error {
                    print("Tidal authentication error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }

                guard let callbackURL = callbackURL else {
                    print("Tidal authentication callback URL missing.")
                    continuation.resume()
                    return
                }

                // Finalize the Tidal login with the callback URL
                Task {
                    await self.finalizeTidalLogin(callbackURL: callbackURL)
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }

    private func finalizeTidalLogin(callbackURL: URL) async {
        do {
            _ = try await TidalAuth.shared.finalizeLogin(loginResponseUri: callbackURL.absoluteString)
            self.isAuthorized = true
            self.currentProvider = .tidal
            self.musicPlayer.setProvider(Tidal(clientId: tidalClientId, clientSecret: tidalClientSecret))
        } catch {
            print("Failed to finalize Tidal login: \(error)")
            self.isAuthorized = false
            self.currentProvider = .none
        }
    }

    public func getTidalCredentialsProvider() -> CredentialsProvider? {
        guard self.currentProvider == .tidal && self.isAuthorized else { return nil }
        return TidalAuth.shared
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}