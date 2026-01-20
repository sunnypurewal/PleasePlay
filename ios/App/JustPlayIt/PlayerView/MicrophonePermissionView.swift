import SwiftUI
import UIKit

struct MicrophonePermissionView: View {
    var onRequestAccess: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title)
                Text("Microphone Access Required")
                    .font(.headline)
            }
            
            Text("Please allow microphone access to use voice commands.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Button("Grant Access") {
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
