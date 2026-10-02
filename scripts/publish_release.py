import os
import sys
import json
import subprocess
import urllib.request
import urllib.parse

def get_github_token():
    p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = p.communicate('protocol=https\nhost=github.com\n\n')
    creds = dict([line.split('=', 1) for line in out.splitlines() if '=' in line])
    return creds.get('password', '')

def main():
    token = get_github_token()
    if not token:
        print('Error: Could not retrieve GitHub token from git credentials')
        sys.exit(1)

    repo = 'SharadS28N/pi-aamps-and-openaamps'
    tag = 'v1.2.6'
    release_name = 'OpenAamps v1.2.6 — Dual Platform Release (Android & iOS) with Lossless Streaming'
    body = """## OpenAamps v1.2.6 Release Notes

### Highlights & Key Improvements

- **Instant Zero-Starvation Audio Streaming**:
  - Resilient AudioPlayerService singleton stream controller architecture.
  - Eliminated playback loading stalls and dual-play race conditions.
  - Progressive pre-buffering with automatic fallback to local PCM cache.

- **Intuitive Sound Studio & Playlist Gestures**:
  - Full support for both direct tap and upward vertical drag/swipe with velocity detection.
  - Visual grab handle bar indicator with crystal-clear affordance.

- **Safe Google Sign-In & Offline Guest Mode**:
  - Zero exposed API secrets or private service credentials.
  - Graceful fallback for Google Play authentication and 1-tap Guest Mode.
  - Automatic playlist and YouTube Music library sync.

- **Complete Dual-Platform Distribution**:
  - Official Android release APK for Android 8.0+.
  - Standalone iOS IPA package for iPhone & iPad (iOS 14.0+) via AltStore, SideStore, Sideloadly, or TrollStore.
  - Official 1-click AltStore repository source manifest (`altstore.json`).

- **Studio DSP & 8D/16D Audio Engine**:
  - 10-band ISO graphic equalizer with audiophile presets.
  - Real-time 8D/16D binaural orbital spatialization and concert hall reverb simulation.
  - Synchronized scrolling karaoke lyrics powered by LRCLIB.

### Release Artifacts
- `OpenAamps-v1.2.6.apk`: Standalone production release package for Android.
- `OpenAamps-latest.apk`: Latest rolling release for Android.
- `OpenAamps-v1.2.6.ipa`: Standalone iOS package for iPhone and iPad.
- `OpenAamps-latest.ipa`: Latest rolling release for iOS.
- `altstore.json`: Official AltStore / SideStore source repository definition.
"""

    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'OpenAamps-Release-Publisher',
        'Content-Type': 'application/json'
    }

    # Check if release already exists
    check_url = f'https://api.github.com/repos/{repo}/releases/tags/{tag}'
    req = urllib.request.Request(check_url, headers=headers)
    release_data = None
    try:
        with urllib.request.urlopen(req) as resp:
            release_data = json.loads(resp.read().decode('utf-8'))
            print(f'Release {tag} already exists with ID: {release_data.get("id")}')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f'Release {tag} does not exist yet. Creating...')
        else:
            print(f'Error checking release: {e}')
            sys.exit(1)

    if not release_data:
        payload = {
            'tag_name': tag,
            'target_commitish': 'main',
            'name': release_name,
            'body': body,
            'draft': False,
            'prerelease': False
        }
        create_url = f'https://api.github.com/repos/{repo}/releases'
        req = urllib.request.Request(create_url, data=json.dumps(payload).encode('utf-8'), headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req) as resp:
                release_data = json.loads(resp.read().decode('utf-8'))
                print(f'Created release {tag} with ID: {release_data.get("id")}')
        except Exception as e:
            print(f'Error creating release: {e}')
            sys.exit(1)
    else:
        # Update release title and body
        update_url = f'https://api.github.com/repos/{repo}/releases/{release_data.get("id")}'
        update_payload = {
            'name': release_name,
            'body': body
        }
        update_req = urllib.request.Request(update_url, data=json.dumps(update_payload).encode('utf-8'), headers=headers, method='PATCH')
        try:
            with urllib.request.urlopen(update_req) as resp:
                release_data = json.loads(resp.read().decode('utf-8'))
                print(f'Updated release {tag} metadata successfully')
        except Exception as e:
            print(f'Warning updating release metadata: {e}')

    release_id = release_data.get('id')

    # Define all assets to upload: (local_path, asset_name, mime_type)
    assets_to_upload = [
        (os.path.join('releases', 'OpenAamps-v1.2.6.apk'), 'OpenAamps-v1.2.6.apk', 'application/vnd.android.package-archive'),
        (os.path.join('releases', 'OpenAamps-latest.apk'), 'OpenAamps-latest.apk', 'application/vnd.android.package-archive'),
        (os.path.join('releases', 'OpenAamps-v1.2.6.ipa'), 'OpenAamps-v1.2.6.ipa', 'application/octet-stream'),
        (os.path.join('releases', 'OpenAamps-latest.ipa'), 'OpenAamps-latest.ipa', 'application/octet-stream'),
        (os.path.join('releases', 'altstore.json'), 'altstore.json', 'application/json'),
    ]

    # Fetch latest release assets to detect existing
    get_assets_url = f'https://api.github.com/repos/{repo}/releases/{release_id}/assets'
    assets_req = urllib.request.Request(get_assets_url, headers=headers)
    current_assets = []
    try:
        with urllib.request.urlopen(assets_req) as resp:
            current_assets = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        print(f'Warning reading current assets: {e}')

    for local_path, asset_name, mime_type in assets_to_upload:
        if not os.path.exists(local_path):
            print(f'Skipping missing local file: {local_path}')
            continue

        file_size = os.path.getsize(local_path)

        # Delete old asset if exists
        for a in current_assets:
            if a.get('name') == asset_name:
                print(f'Deleting old asset {asset_name} (ID: {a.get("id")})...')
                del_url = f'https://api.github.com/repos/{repo}/releases/assets/{a.get("id")}'
                del_req = urllib.request.Request(del_url, headers=headers, method='DELETE')
                try:
                    with urllib.request.urlopen(del_req):
                        pass
                except Exception as del_err:
                    print(f'Warning deleting asset {asset_name}: {del_err}')

        upload_url = f'https://uploads.github.com/repos/{repo}/releases/{release_id}/assets?name={asset_name}'
        upload_headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'OpenAamps-Release-Publisher',
            'Content-Type': mime_type,
            'Content-Length': str(file_size)
        }

        print(f'Uploading {asset_name} ({file_size} bytes) to GitHub Release...')
        with open(local_path, 'rb') as f:
            upload_req = urllib.request.Request(upload_url, data=f.read(), headers=upload_headers, method='POST')
            try:
                with urllib.request.urlopen(upload_req) as up_resp:
                    up_data = json.loads(up_resp.read().decode('utf-8'))
                    print(f'Uploaded {asset_name} successfully: {up_data.get("browser_download_url")}')
            except Exception as up_err:
                print(f'Error uploading {asset_name}: {up_err}')

    print('All release assets successfully synced to GitHub Release!')

if __name__ == '__main__':
    main()
