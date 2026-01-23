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
	case appleMusic = "APPLE_MUSIC"
	case spotify = "SPOTIFY"
	case tidal = "TIDAL"
	case youtube = "YOUTUBE"
	case none
}

@MainActor
public class AuthorizationManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published public var isAuthorized: Bool = false
    @Published public var isLoading: Bool = true
    @Published public var currentProvider: StreamingProvider = .none

    private var tidalClientId: String = "P7AYqSKY9Slcppll" // Replace with actual ID
    private var tidalClientSecret: String = "Wnb5SD6xV2gBz6CRWN3ipJNQ0QcGv3Piudmy8m1lcc=" // Replace with actual Secret

	public override init() {
        super.init()

		let config = AuthConfig(
			clientId: tidalClientId,
			clientSecret: tidalClientSecret,
			credentialsKey: "tidal_credentials", // Key for storing credentials in Keychain
			scopes: [] // Example scopes
		)
		TidalAuth.shared.config(config: config)
		do {
			try TidalAuth.shared.logout()
		} catch {
			print("Failed to logout Tidal: \(error)")
		}
        Task {
            await checkAuthorization()
        }
    }

    public func checkAuthorization() async {
        // Check for stored provider and credentials
        let appleMusicStatus = MusicAuthorization.currentStatus
        if appleMusicStatus == .authorized {
            self.isAuthorized = true
            self.currentProvider = .appleMusic
        } else if TidalAuth.shared.isUserLoggedIn {
            self.isAuthorized = true
            self.currentProvider = .tidal
        } else {
            self.isAuthorized = false
            self.currentProvider = .none
        }
        self.isLoading = false
    }

    public func authorizeAppleMusic() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            self.isAuthorized = true
            self.currentProvider = .appleMusic
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

    public func providerForCurrentSelection() -> StreamingMusicProvider? {
        switch currentProvider {
        case .appleMusic:
            return AppleMusic()
        case .tidal:
            return Tidal(clientId: tidalClientId, clientSecret: tidalClientSecret)
        case .spotify, .youtube, .none:
            return nil
        }
    }
}
