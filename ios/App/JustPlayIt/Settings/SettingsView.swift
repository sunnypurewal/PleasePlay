import SwiftUI
import MusicStreaming

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthorizationManager
    @AppStorage("explicitFilterEnabled") private var explicitFilterEnabled = true
    @AppStorage("explicitFilterPin") private var explicitFilterPin: String?

    @State private var showPinEntrySheet = false
    @State private var showPinSetupSheet = false
    @State private var pinInput = ""
    @State private var pinError: String?
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var setupError: String?
    @State private var pinEntryMode: PinEntryMode?

    private enum PinEntryMode {
        case disableFilter
        case removePin
    }

    private var explicitFilterBinding: Binding<Bool> {
        Binding(
            get: { explicitFilterEnabled },
            set: { newValue in
                if !newValue {
                    if explicitFilterPin != nil {
                        pinEntryMode = .disableFilter
                        pinInput = ""
                        pinError = nil
                        showPinEntrySheet = true
                        return
                    }
                    explicitFilterEnabled = false
                    explicitFilterPin = nil
                    return
                }

                explicitFilterEnabled = true
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Explicit Content") {
                    Toggle("Filter explicit songs", isOn: explicitFilterBinding)
                    if explicitFilterPin != nil {
                        Text("Changes require the PIN, preventing the filter from being disabled without approval.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if explicitFilterPin == nil {
                        Button("Add a PIN lock") {
                            preparePinSetup()
                        }
                    } else {
                        Button("Change PIN") {
                            preparePinSetup()
                        }
                        Button("Remove PIN", role: .destructive) {
                            pinEntryMode = .removePin
                            pinInput = ""
                            pinError = nil
                            showPinEntrySheet = true
                        }
                    }
                }

                if !authManager.isAuthorized {
                    Section("Connect a provider") {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }

                        Button(action: {}) {
                            HStack {
                                Text("Connect Spotify")
                                    .fontWeight(.semibold)
                                Text("– coming soon")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .disabled(true)

                        Button(action: {
                            Task {
                                do {
                                    try await authManager.authorizeTidal()
                                } catch {
                                    print("Failed to connect to Tidal: \(error)")
                                }
                            }
                        }) {
                            HStack {
                                Text("Connect Tidal")
                                    .fontWeight(.semibold)
                                Text("– coming soon")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPinEntrySheet) {
                pinEntrySheet
            }
            .sheet(isPresented: $showPinSetupSheet) {
                pinSetupSheet
            }
        }
    }

    private func preparePinSetup() {
        newPin = ""
        confirmPin = ""
        setupError = nil
        showPinSetupSheet = true
    }

    private var pinEntrySheet: some View {
        NavigationStack {
            Form {
                SecureField("Enter PIN", text: $pinInput)
                    .keyboardType(.numberPad)
                    .onChange(of: pinInput) { pinInput = sanitizePinText($0) }
                Text(pinEntryMode == .removePin ? "Enter PIN to remove the lock." : "Enter PIN to disable the filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let error = pinError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Enter PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        closePinEntry()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        verifyPinEntry()
                    }
                    .disabled(pinInput.isEmpty)
                }
            }
        }
    }

    private var pinSetupSheet: some View {
        NavigationStack {
            Form {
                SecureField("New PIN", text: $newPin)
                    .keyboardType(.numberPad)
                    .onChange(of: newPin) { newPin = sanitizePinText($0) }
                SecureField("Confirm PIN", text: $confirmPin)
                    .keyboardType(.numberPad)
                    .onChange(of: confirmPin) { confirmPin = sanitizePinText($0) }
                Text("This PIN prevents the explicit filter from being disabled without the code.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let error = setupError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Add PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPinSetupSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePin()
                    }
                    .disabled(newPin.isEmpty || confirmPin.isEmpty)
                }
            }
        }
    }

    private func verifyPinEntry() {
        guard let storedPin = explicitFilterPin else {
            closePinEntry()
            return
        }

        if pinInput == storedPin {
            switch pinEntryMode {
            case .disableFilter:
                explicitFilterEnabled = false
                explicitFilterPin = nil
            case .removePin:
                explicitFilterPin = nil
            case .none:
                break
            }
            closePinEntry()
        } else {
            pinError = "Incorrect PIN"
        }
    }

    private func closePinEntry() {
        showPinEntrySheet = false
        pinEntryMode = nil
        pinInput = ""
        pinError = nil
    }

    private func savePin() {
        guard newPin == confirmPin else {
            setupError = "PINs must match"
            return
        }
        guard newPin.count == 4 else {
            setupError = "PIN must be 4 digits"
            return
        }
        explicitFilterPin = newPin
        setupError = nil
        showPinSetupSheet = false
    }

    private func sanitizePinText(_ text: String) -> String {
        String(text.filter(\.isNumber).prefix(4))
    }
}
