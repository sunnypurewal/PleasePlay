//
//  MicrophoneStatusView.swift
//  JustPlayIt
//

import SwiftUI

struct MicrophoneStatusView<R: AudioRecording>: View {
    let recorder: R
    @Binding var isAutomaticListeningEnabled: Bool
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                
                Button(action: { Task { try? await recorder.toggleRecording() } }) {
                    if recorder.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.5
                                    }
                                }
                            Text("Microphone is listening")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 8, height: 8)
                            Text("Microphone is not listening")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { Task { try? await recorder.toggleRecording() } }) {
                    Image(systemName: recorder.isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.title3)
                        .foregroundColor(recorder.isRecording ? .accentColor : .secondary)
                        .padding(10)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            HStack(spacing: 8) {
                Spacer()
                Text("Auto Listen")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Toggle("", isOn: $isAutomaticListeningEnabled)
                    .labelsHidden()
                    .fixedSize()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: isAutomaticListeningEnabled) { _, isEnabled in
            Task {
                if isEnabled {
                    if !recorder.isRecording {
                        try? await recorder.record()
                    }
                } else if recorder.isRecording {
                    try? await recorder.stopRecording()
                }
            }
        }
    }
}
