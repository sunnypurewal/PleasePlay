import jwt
import time
import requests
import os
import json

# Configuration
KEY_ID = '6BLN7U6STP'
P8_FILE = 'AuthKey_6BLN7U6STP.p8'
TEAM_ID = os.getenv('APPLE_TEAM_ID', 'ZG82TFXU3C')
ALG = 'ES256'
TOKEN_TTL = 3600

def load_private_key(filename):
    with open(filename, 'r') as f:
        return f.read()

def generate_developer_token(team_id, key_id, private_key_content):
    headers = {
        'alg': ALG,
        'kid': key_id
    }
    current_time = int(time.time())
    payload = {
        'iss': team_id,
        'iat': current_time,
        'exp': current_time + TOKEN_TTL
    }
    return jwt.encode(payload, private_key_content, algorithm=ALG, headers=headers)

def fetch_apple_api(url, token):
    headers = {
        'Authorization': f'Bearer {token}'
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error fetching {url}: {response.status_code}")
        print(response.text)
        return None

def download_file(url, filename):
    print(f"Downloading {filename}...")
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
    print(f"Successfully downloaded {filename}")

def main():
    if not os.path.exists(P8_FILE):
        print(f"Error: Private key file '{P8_FILE}' not found.")
        return

    try:
        private_key = load_private_key(P8_FILE)
        token = generate_developer_token(TEAM_ID, KEY_ID, private_key)
        print("Developer Token generated successfully.")
        
        # 1. Get the latest export for 'song' dataset
        # Possible values: album, song, artist, popularityTopChartAlbums, popularityTopChartSongs
        dataset = 'song'
        latest_url = f"https://api.media.apple.com/v1/feed/{dataset}/latest"
        latest_data = fetch_apple_api(latest_url, token)
        
        if not latest_data or 'data' not in latest_data or not latest_data['data']:
            print("Could not find latest export.")
            return
            
        export_id = latest_data['data'][0]['id']
        print(f"Latest Export ID: {export_id}")
        
        # 2. Get the parts for this export
        parts_url = f"https://api.media.apple.com/v1/feed/exports/{export_id}/parts"
        parts_data = fetch_apple_api(parts_url, token)
        
        if not parts_data or 'resources' not in parts_data or 'parts' not in parts_data['resources']:
            print("Could not find parts for this export.")
            return
            
        parts_resources = parts_data['resources']['parts']
        print(f"Found {len(parts_resources)} parts.")
        
        # 3. Download the first part as a sample
        # The keys in parts_resources are the part IDs
        first_part_id = list(parts_resources.keys())[0]
        first_part = parts_resources[first_part_id]
        
        attributes = first_part.get('attributes', {})
        download_url = attributes.get('exportLocation')
        
        if not download_url:
            print(f"No download URL (exportLocation) found for part {first_part_id}")
            return
            
        # Generate a filename
        # The URL contains the filename: .../part-00000-...gz.parquet?...
        # We'll use a simpler name if needed, but let's try to extract from URL or use ID
        filename = f"{dataset}_{export_id}_part0.parquet.gz"
        
        download_file(download_url, filename)
        
        # Save metadata for reference
        with open('feed_metadata.json', 'w') as f:
            json.dump(latest_data, f, indent=2)
        print("Saved feed metadata to 'feed_metadata.json'")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()