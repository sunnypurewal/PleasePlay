import time
import jwt
import requests
import os
import json

# --- Configuration ---
# You can get these from App Store Connect -> Users and Access -> Keys
ISSUER_ID = os.getenv('APP_STORE_ISSUER_ID', '69a6de88-aaae-47e3-e053-5b8c7c11a4d1')
KEY_ID = os.getenv('APP_STORE_KEY_ID', '73Z5Y2U8MH')
PRIVATE_KEY_PATH = os.getenv('APP_STORE_PRIVATE_KEY_PATH', '/Users/sunny/Downloads/AuthKey_73Z5Y2U8MH.p8')
BUNDLE_ID = os.getenv('APP_BUNDLE_ID', 'com.riddimsoftware.justplayit')

# API Endpoints
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

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
    print("App not found.")
    return None

def get_app_info_id(token, app_id):
    """Gets the AppInfo ID for a specific app."""
    # AppInfo contains content rights and references to age ratings
    result = api_request("GET", f"apps/{app_id}/appInfos", token)
    if result and result['data']:
        return result['data'][0]['id']
    return None

def get_age_rating_declaration_id(token, app_info_id):
    """Gets the AgeRatingDeclaration ID for an appInfo."""
    result = api_request("GET", f"appInfos/{app_info_id}/ageRatingDeclaration", token)
    if result and 'data' in result:
        return result['data']['id']
    return None

def setup_age_ratings(token, age_rating_id):
    """Sets default age rating declarations."""
    print(f"Updating Age Rating Declaration ({age_rating_id})...")
    data = {
        "data": {
            "type": "ageRatingDeclarations",
            "id": age_rating_id,
            "attributes": {
                "advertising": False,
                "ageAssurance": False,
                "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                "contests": "NONE",
                "gambling": False,
                "gamblingSimulated": "NONE",
                "gunsOrOtherWeapons": "NONE",
                "healthOrWellnessTopics": False,
                "horrorOrFearThemes": "NONE",
                "lootBox": False,
                "matureOrSuggestiveThemes": "NONE",
                "medicalOrTreatmentInformation": "NONE",
                "messagingAndChat": False,
                "parentalControls": False,
                "profanityOrCrudeHumor": "NONE",
                "sexualContentGraphicAndNudity": "NONE",
                "sexualContentOrNudity": "NONE",
                "unrestrictedWebAccess": False,
                "userGeneratedContent": False,
                "violenceCartoonOrFantasy": "NONE",
                "violenceRealistic": "NONE",
                "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                "ageRatingOverrideV2": "NONE",
                "koreaAgeRatingOverride": "NONE"
            }
        }
    }
    return api_request("PATCH", f"ageRatingDeclarations/{age_rating_id}", token, data)


def setup_content_rights(token, app_id):
    """Sets the Content Rights Declaration for the app."""
    print(f"Updating Content Rights for App ({app_id})...")
    data = {
        "data": {
            "type": "apps",
            "id": app_id,
            "attributes": {
                "contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"
            }
        }
    }
    return api_request("PATCH", f"apps/{app_id}", token, data)

def main():
    if ISSUER_ID == 'YOUR_ISSUER_ID' or KEY_ID == 'YOUR_KEY_ID':
        print("Please set your APP_STORE_ISSUER_ID and APP_STORE_KEY_ID environment variables.")
        return

    token = get_token()
    if not token:
        return

    # 1. Get App ID
    app_id = get_app_id(token, BUNDLE_ID)
    if not app_id: return

    # 3. Setup Content Rights
    setup_content_rights(token, app_id)

    # 4. Setup Age Ratings (App Info level)
    app_info_id = get_app_info_id(token, app_id)
    if app_info_id:
        age_rating_id = get_age_rating_declaration_id(token, app_info_id)
        if age_rating_id:
            setup_age_ratings(token, age_rating_id)
        else:
            print("Could not find Age Rating Declaration.")
    else:
        print("Could not find App Info.")

    print("\n✅ App setup completed successfully.")

if __name__ == "__main__":
    main()
