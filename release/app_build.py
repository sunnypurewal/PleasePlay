import subprocess
import os
import sys
import time

# --- Configuration ---
WORKSPACE = "../ios/JustPlayIt.xcworkspace"
SCHEME = "JustPlayIt"
TEAM_ID = "ZG82TFXU3C"
BUNDLE_ID = "com.riddimsoftware.justplayit"
EXPORT_PATH = "./build"
ARCHIVE_PATH = f"{EXPORT_PATH}/{SCHEME}.xcarchive"
IPA_PATH = f"{EXPORT_PATH}/JustPlayIt.ipa"
EXPORT_OPTIONS_PLIST = "ExportOptions.plist"

# App Store Connect API Credentials (for upload)
KEY_ID = "73Z5Y2U8MH"
ISSUER_ID = "69a6de88-aaae-47e3-e053-5b8c7c11a4d1"
PRIVATE_KEY_PATH = "/Users/sunny/Downloads/AuthKey_73Z5Y2U8MH.p8"

def run_command(command, cwd=None):
    """Utility to run shell commands and print output in real-time."""
    print(f"Running: {' '.join(command)}")
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=cwd
    )
    for line in process.stdout:
        print(line, end="")
    process.wait()
    if process.returncode != 0:
        print(f"❌ Command failed with return code {process.returncode}")
        sys.exit(1)
    return True

def create_export_options():
    """Generates the ExportOptions.plist file required for ipa export."""
    content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>{BUNDLE_ID}</key>
        <string>AppStore_{BUNDLE_ID}</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>{TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
"""
    # Note: Using manual signing above. If the user uses automatic signing, 
    # we can simplify this to method: app-store and signingStyle: automatic.
    # Given the previous context, let's try automatic first as it's more standard for CI.
    
    automatic_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>{TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
"""
    with open(EXPORT_OPTIONS_PLIST, 'w') as f:
        f.write(automatic_content)
    print(f"✅ Created {EXPORT_OPTIONS_PLIST}")

def build_app():
    """Cleans, archives, and exports the app."""
    if not os.path.exists(EXPORT_PATH):
        os.makedirs(EXPORT_PATH)

    # 1. Clean
    print("🧹 Cleaning...")
    run_command([
        "xcodebuild", "clean",
        "-workspace", WORKSPACE,
        "-scheme", SCHEME
    ])

    # 2. Archive
    print("📦 Archiving...")
    run_command([
        "xcodebuild", "archive",
        "-workspace", WORKSPACE,
        "-scheme", SCHEME,
        "-archivePath", ARCHIVE_PATH,
        "-allowProvisioningUpdates"
    ])

    # 3. Export IPA
    print("🚀 Exporting IPA...")
    create_export_options()
    run_command([
        "xcodebuild", "-exportArchive",
        "-archivePath", ARCHIVE_PATH,
        "-exportPath", EXPORT_PATH,
        "-exportOptionsPlist", EXPORT_OPTIONS_PLIST,
        "-allowProvisioningUpdates"
    ])
    
    # Check if export resulted in an IPA. Path might vary, let's find it.
    # Usually it's exported to {EXPORT_PATH}/{SCHEME}.ipa or just {EXPORT_PATH}
    print("Finding exported IPA...")
    for root, dirs, files in os.walk(EXPORT_PATH):
        for file in files:
            if file.endswith(".ipa"):
                global IPA_PATH
                IPA_PATH = os.path.join(root, file)
                print(f"✅ IPA found at: {IPA_PATH}")
                return True
    
    print("❌ Failed to find exported IPA.")
    sys.exit(1)

def upload_to_app_store():
    """Uploads the IPA to App Store Connect using altool."""
    print("☁️ Uploading to App Store Connect...")
    
    # xcrun altool expects the private key to be in ~/.private_keys or ~/private_keys
    # with the filename format: AuthKey_<KEY_ID>.p8
    home = os.path.expanduser("~")
    private_keys_dir = os.path.join(home, ".private_keys")
    expected_key_path = os.path.join(private_keys_dir, f"AuthKey_{KEY_ID}.p8")
    
    if not os.path.exists(expected_key_path):
        print(f"🔑 Preparing private key in {private_keys_dir}...")
        if not os.path.exists(private_keys_dir):
            os.makedirs(private_keys_dir)
        
        if os.path.exists(PRIVATE_KEY_PATH):
            subprocess.run(["cp", PRIVATE_KEY_PATH, expected_key_path])
        else:
            print(f"❌ Error: Private key not found at {PRIVATE_KEY_PATH}. altool will fail.")
            sys.exit(1)

    # Using altool with the API Key
    run_command([
        "xcrun", "altool",
        "--upload-app",
        "--type", "ios",
        "--file", IPA_PATH,
        "--apiKey", KEY_ID,
        "--apiIssuer", ISSUER_ID
    ])
    print("✅ Upload successful!")

def main():
    start_time = time.time()
    
    try:
        build_app()
        upload_to_app_store()
    finally:
        # Cleanup
        if os.path.exists(EXPORT_OPTIONS_PLIST):
            os.remove(EXPORT_OPTIONS_PLIST)
            
    end_time = time.time()
    duration = end_time - start_time
    print(f"\n✨ Total Time: {duration/60:.2f} minutes")

if __name__ == "__main__":
    main()
