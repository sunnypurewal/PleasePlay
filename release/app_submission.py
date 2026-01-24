import time
import jwt
import requests
import os
import json

# --- Configuration ---
# App Store Connect Credentials
ISSUER_ID = os.getenv('APP_STORE_ISSUER_ID', '69a6de88-aaae-47e3-e053-5b8c7c11a4d1')
KEY_ID = os.getenv('APP_STORE_KEY_ID', '73Z5Y2U8MH')
PRIVATE_KEY_PATH = os.getenv('APP_STORE_PRIVATE_KEY_PATH', '/Users/sunny/Downloads/AuthKey_73Z5Y2U8MH.p8')
BUNDLE_ID = os.getenv('APP_BUNDLE_ID', 'com.riddimsoftware.justplayit')

# API Endpoints
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

# --- Submission Metadata ---
VERSION_STRING = "1.0" 
COPYRIGHT = f"Riddim Software Corporation"
RELEASE_TYPE = "AFTER_APPROVAL"  # MANUAL, AFTER_APPROVAL, or SCHEDULED

# Localized Metadata (en-US)
LOCALE = "en-US"
PROMOTIONAL_TEXT = "The easiest way to play and discover music."
DESCRIPTION = "Sonnio makes it easier than ever for the whole family to play and discover music together."
KEYWORDS = "music, spotify, deezer, tidal, artificial intelligence, player, playlist, riddim, voice activated, kid friendly, kids music, family, shazam"
SUPPORT_URL = "https://sonnio.riddimsoftware.com/support"
MARKETING_URL = "https://sonnio.riddimsoftware.com"

# App Review Information
# Note: Phone number must include '+' and country code, for example: +1 415 555 1212
REVIEW_FIRST_NAME = "Sunny"
REVIEW_LAST_NAME = "Purewal"
REVIEW_PHONE = "+1 365 357 1223"
REVIEW_EMAIL = "sunny@riddimsoftware.com"
DEMO_ACCOUNT_REQUIRED = False # Set to True if your app requires a login
DEMO_ACCOUNT_NAME = ""
DEMO_ACCOUNT_PASSWORD = ""
REVIEW_NOTES = ""

def get_token():
    """Generates a JWT for App Store Connect API."""
    if not os.path.exists(PRIVATE_KEY_PATH):
        print(f"Error: Private key file {PRIVATE_KEY_PATH} not found.")
        return None

    with open(PRIVATE_KEY_PATH, 'r') as f:
        private_key = f.read()

    header = {
        "alg": "ES256",
        "kid": KEY_ID,
        "typ": "JWT"
    }

    payload = {
        "iss": ISSUER_ID,
        "exp": int(time.time()) + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1"
    }

    token = jwt.encode(payload, private_key, algorithm="ES256", headers=header)
    return token

def api_request(method, endpoint, token, data=None):
    """Helper to make API requests."""
    url = f"{BASE_URL}/{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    if method == "GET":
        response = requests.get(url, headers=headers)
    elif method == "PATCH":
        response = requests.patch(url, headers=headers, json=data)
    elif method == "POST":
        response = requests.post(url, headers=headers, json=data)
    else:
        raise ValueError(f"Unsupported method: {method}")

    if response.status_code not in [200, 201, 204]:
        print(f"Error {response.status_code} on {endpoint}: {response.text}")
        return None
    
    return response.json() if response.status_code != 204 else True

def get_app_id(token, bundle_id):
    """Finds the Internal App ID for a given bundle identifier."""
    print(f"Finding app with bundle ID: {bundle_id}...")
    result = api_request("GET", f"apps?filter[bundleId]={bundle_id}", token)
    if result and result['data']:
        return result['data'][0]['id']
    return None

def get_or_create_version(token, app_id, version_string):
    """Finds an existing version or creates a new one in PREPARE_FOR_SUBMISSION state."""
    print(f"Checking for IOS version {version_string}...")
    # Filter by version string AND platform to be precise
    result = api_request("GET", f"apps/{app_id}/appStoreVersions?filter[versionString]={version_string}&filter[platform]=IOS", token)
    
    if result and result['data']:
        version_id = result['data'][0]['id']
        state = result['data'][0]['attributes']['appStoreState']
        print(f"Found existing IOS version: {version_id} (State: {state})")
        if state != 'PREPARE_FOR_SUBMISSION':
            print(f"⚠️  Warning: Version {version_string} is in {state} state and cannot be edited.")
            # If the target version is locked, try to find ANY editable version as a fallback
            print("Checking if any other version is in 'PREPARE_FOR_SUBMISSION'...")
        else:
            return version_id
    
    # Check for ANY IOS version in PREPARE_FOR_SUBMISSION
    result = api_request("GET", f"apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION&filter[platform]=IOS", token)
    if result and result['data']:
        version_id = result['data'][0]['id']
        found_version = result['data'][0]['attributes']['versionString']
        print(f"Found version {found_version} in prepare state. Using ID: {version_id}")
        return version_id

    # Create new version if nothing is in prepare state
    print(f"Creating new IOS version {version_string}...")
    data = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "versionString": version_string,
                "platform": "IOS",
                "releaseType": RELEASE_TYPE
            },
            "relationships": {
                "app": {
                    "data": {
                        "type": "apps",
                        "id": app_id
                    }
                }
            }
        }
    }
    result = api_request("POST", "appStoreVersions", token, data)
    if result:
        return result['data']['id']
    return None

def update_version_attributes(token, version_id):
    """Updates version-level attributes like copyright and release type."""
    print(f"Updating attributes for version {version_id}...")
    data = {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {
                "copyright": COPYRIGHT,
                "releaseType": RELEASE_TYPE
            }
        }
    }
    return api_request("PATCH", f"appStoreVersions/{version_id}", token, data)

def update_localizations(token, version_id):
    """Updates localized metadata for the version."""
    print(f"Updating localizations for version {version_id}...")
    result = api_request("GET", f"appStoreVersions/{version_id}/appStoreVersionLocalizations?filter[locale]={LOCALE}", token)
    
    loc_id = None
    if result and result['data']:
        loc_id = result['data'][0]['id']
        print(f"Updating existing localization: {loc_id}")
    else:
        print(f"Creating new localization for {LOCALE}...")
        data = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {
                    "locale": LOCALE
                },
                "relationships": {
                    "appStoreVersion": {
                        "data": {
                            "type": "appStoreVersions",
                            "id": version_id
                        }
                    }
                }
            }
        }
        res = api_request("POST", "appStoreVersionLocalizations", token, data)
        if res:
            loc_id = res['data']['id']

    if loc_id:
        data = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": loc_id,
                "attributes": {
                    "promotionalText": PROMOTIONAL_TEXT,
                    "description": DESCRIPTION,
                    "keywords": KEYWORDS,
                    "supportUrl": SUPPORT_URL,
                    "marketingUrl": MARKETING_URL
                }
            }
        }
        return api_request("PATCH", f"appStoreVersionLocalizations/{loc_id}", token, data)
    return None

def update_review_detail(token, version_id):
    """Updates App Review information."""
    print(f"Updating review detail for version {version_id}...")
    result = api_request("GET", f"appStoreVersions/{version_id}/appStoreReviewDetail", token)
    
    review_id = None
    if result and 'data' in result and result['data']:
        review_id = result['data']['id']
    
    attributes = {
        "contactFirstName": REVIEW_FIRST_NAME,
        "contactLastName": REVIEW_LAST_NAME,
        "contactPhone": REVIEW_PHONE,
        "contactEmail": REVIEW_EMAIL,
        "demoAccountRequired": DEMO_ACCOUNT_REQUIRED,
        "demoAccountName": DEMO_ACCOUNT_NAME,
        "demoAccountPassword": DEMO_ACCOUNT_PASSWORD,
        "notes": REVIEW_NOTES
    }

    if review_id:
        print(f"Updating existing review detail: {review_id}")
        data = {
            "data": {
                "type": "appStoreReviewDetails",
                "id": review_id,
                "attributes": attributes
            }
        }
        return api_request("PATCH", f"appStoreReviewDetails/{review_id}", token, data)
    else:
        print("Review detail not found, creating new one...")
        data = {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attributes,
                "relationships": {
                    "appStoreVersion": {
                        "data": {
                            "type": "appStoreVersions",
                            "id": version_id
                        }
                    }
                }
            }
        }
        return api_request("POST", "appStoreReviewDetails", token, data)

def link_latest_build(token, app_id, version_id):
    """Finds the latest build and links it to the version."""
    print(f"Linking latest build for app {app_id} to version {version_id}...")
    # Use the /v1/builds endpoint with a filter on app ID for better sorting support
    result = api_request("GET", f"builds?filter[app]={app_id}&sort=-uploadedDate&limit=1", token)
    
    if result and result['data']:
        build_id = result['data'][0]['id']
        build_version = result['data'][0]['attributes']['version']
        print(f"Linking build {build_id} (Version: {build_version})...")
        
        data = {
            "data": {
                "type": "builds",
                "id": build_id
            }
        }
        return api_request("PATCH", f"appStoreVersions/{version_id}/relationships/build", token, data)
    else:
        print("No builds found to link.")
    return None

def main():
    token = get_token()
    if not token: return

    # 1. Identify App
    app_id = get_app_id(token, BUNDLE_ID)
    if not app_id: return

    # 2. Identify/Create Version
    version_id = get_or_create_version(token, app_id, VERSION_STRING)
    if not version_id: return

    # 3. Update core attributes
    update_version_attributes(token, version_id)

    # 4. Update localized metadata (Promo, Desc, etc)
    update_localizations(token, version_id)

    # 5. Update Review Info
    update_review_detail(token, version_id)

    # 6. Link Build
    link_latest_build(token, app_id, version_id)

    print("\n✅ App submission update completed successfully.")

if __name__ == "__main__":
    main()
