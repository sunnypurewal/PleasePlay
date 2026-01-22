//
//  MicrophoneStatusView.swift
//  JustPlayIt
//

import SwiftUI

struct MicrophoneStatusView: View {
    let isListening: Bool
    @Binding var isAutomaticListeningEnabled: Bool
    @EnvironmentObject private var recognitionState: RecognitionListeningState
    let toggleListening: () async -> Void
    let onAutomaticListeningChanged: (Bool) async -> Void
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Button(action: {
                    guard !recognitionState.isMusicRecognitionActive else { return }
                    Task {
                        await toggleListening()
                    }
                }) {
                    if recognitionState.isMusicRecognitionActive {
                        statusLabel(text: "Voice listening paused", accent: .orange)
                    } else if isListening {
                        listeningStatusLabel()
                    } else {
                        statusLabel(text: "Microphone is not listening", accent: .secondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)

                Button(action: {
                    guard !recognitionState.isMusicRecognitionActive else { return }
                    Task {
                        await toggleListening()
                    }
                }) {
                    Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                        .font(.title3)
                        .foregroundColor(isListening ? .accentColor : .secondary)
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
                    .disabled(recognitionState.isMusicRecognitionActive)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: isAutomaticListeningEnabled) { _, isEnabled in
            Task {
                await onAutomaticListeningChanged(isEnabled)
            }
        }
    }

    @ViewBuilder
    private func statusLabel(text: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func listeningStatusLabel() -> some View {
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
    }
}
