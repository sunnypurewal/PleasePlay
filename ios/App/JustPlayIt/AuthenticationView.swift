//
//  AuthenticationView.swift
//  JustPlayIt
//
//  Created by Sunny on 2026-01-16.
//

import SwiftUI
import MusicStreaming

struct AuthenticationView: View {
	@EnvironmentObject var authManager: AuthorizationManager
	
	var body: some View {
		VStack(spacing: 20) {
			Spacer()
			
			Text("please play")
				.font(.largeTitle)
				.fontWeight(.bold)
				.padding(.bottom, 40)
			
			// Apple Music
			Button(action: {
				Task {
					await authManager.authorizeAppleMusic()
				}
			}) {
				HStack {
					Image(systemName: "applelogo")
					Text("Connect Apple Music")
						.fontWeight(.semibold)
				}
				.frame(width: 280)
				.padding()
				.background(Color.red) // Apple Music often uses a red/pink accent
				.foregroundColor(.white)
				.cornerRadius(12)
				.accessibilityIdentifier("appleMusicButton")
			}
			
			// Spotify
			Button(action: {
				// TODO: Implement Spotify Auth
			}) {
				HStack {
					// In a real app, you would include the Spotify logo asset here
					Text("Connect Spotify")
						.fontWeight(.semibold)
				}
				.frame(width: 280)
				.padding()
				.background(Color(red: 29/255, green: 185/255, blue: 84/255))
				.foregroundColor(.white)
				.cornerRadius(12)
			}
			
			// Tidal
			Button(action: {
				Task {
					do {
						try await authManager.authorizeTidal()
					} catch {
						print("Error authorizing Tidal: \(error.localizedDescription)")
					}
				}
			}) {
				HStack {
					// In a real app, you would include the Tidal logo asset here
					Text("Connect Tidal")
						.fontWeight(.semibold)
				}
				.frame(width: 280)
				.padding()
				.background(Color.black)
				.foregroundColor(.white)
				.cornerRadius(12)
			}
			
			Spacer()
		}
		.padding(.horizontal, 30)
	}
}

#Preview {
	AuthenticationView()
		.environmentObject(AuthorizationManager())
}
