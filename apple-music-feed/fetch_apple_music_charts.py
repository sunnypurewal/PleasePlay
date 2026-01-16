import jwt
import time
import requests
import os

# Configuration
KEY_ID = '6BLN7U6STP'
P8_FILE = 'AuthKey_6BLN7U6STP.p8'
TEAM_ID = os.getenv('APPLE_TEAM_ID', 'YOUR_TEAM_ID')  # Replace with your Team ID
ALG = 'ES256'
TOKEN_TTL = 3600  # 1 hour

def load_private_key(filename):
    with open(filename, 'r') as f:
        return f.read()

def generate_developer_token(team_id, key_id, private_key_content):
    headers = {
        'alg': ALG,
        'kid': key_id
    }
    
    current_time = int(time.time())
    exp_time = current_time + TOKEN_TTL
    
    payload = {
        'iss': team_id,
        'iat': current_time,
        'exp': exp_time
    }
    
    token = jwt.encode(payload, private_key_content, algorithm=ALG, headers=headers)
    return token

def fetch_feed(token, storefront='us'):
    url = f"https://api.music.apple.com/v1/catalog/{storefront}/charts"
    params = {
        'types': 'songs,albums,playlists',
        'limit': 10
    }
    
    headers = {
        'Authorization': f'Bearer {token}'
    }
    
    print(f"Fetching data from: {url}")
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code}")
        print(response.text)
        return None

def main():
    if TEAM_ID == 'YOUR_TEAM_ID':
        print("Error: Please set your Apple Team ID in the script or via APPLE_TEAM_ID environment variable.")
        return

    if not os.path.exists(P8_FILE):
        print(f"Error: Private key file '{P8_FILE}' not found.")
        return

    try:
        private_key = load_private_key(P8_FILE)
        token = generate_developer_token(TEAM_ID, KEY_ID, private_key)
        print("Developer Token generated successfully.")
        
        # Verify/Fetch data
        data = fetch_feed(token)
        
        if data:
            import json
            output_file = 'apple_music_feed.json'
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2)
            print(f"Successfully downloaded feed metadata to '{output_file}'")
            
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
