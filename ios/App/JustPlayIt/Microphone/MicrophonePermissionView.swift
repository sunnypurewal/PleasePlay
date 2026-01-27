import SwiftUI
import UIKit

struct MicrophonePermissionView: View {
    var isDenied: Bool = false
    var onRequestAccess: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title)
                Text(isDenied ? "Microphone Access Denied" : "Microphone Access Required")
                    .font(.headline)
            }
            
            Text(isDenied ? "Please enable microphone access in Settings to use voice commands." : "Voice commands require microphone access.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Button(isDenied ? "Open Settings" : "Enable") {
                onRequestAccess()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 1)
        )
        .padding()
    }
}

#Preview {
    MicrophonePermissionView(onRequestAccess: {})
}
