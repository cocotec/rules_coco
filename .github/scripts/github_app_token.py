#!/usr/bin/env python3
"""Generate GitHub App installation token using Google Cloud KMS for signing."""

import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode()


def sign_with_kms(message: str, project: str, location: str, keyring: str,
                  key: str, version: str) -> bytes:
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt') as msg_file, \
         tempfile.NamedTemporaryFile(mode='rb', suffix='.sig') as sig_file:
        msg_file.write(message)
        msg_file.flush()

        subprocess.run([
            'gcloud',
            'kms',
            'asymmetric-sign',
            '--project',
            project,
            '--location',
            location,
            '--keyring',
            keyring,
            '--key',
            key,
            '--version',
            version,
            '--digest-algorithm',
            'sha256',
            '--input-file',
            msg_file.name,
            '--signature-file',
            sig_file.name,
        ],
                       check=True,
                       capture_output=True)

        return open(sig_file.name, 'rb').read()


def create_jwt(app_id: str, project: str, location: str, keyring: str,
               key: str, version: str) -> str:
    now = int(time.time())
    message = f"{b64url(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())}." \
              f"{b64url(json.dumps({'iat': now - 60, 'exp': now + 600, 'iss': app_id}).encode())}"
    return f"{message}.{b64url(sign_with_kms(message, project, location, keyring, key, version))}"


def get_installation_token(jwt: str, installation_id: str) -> str:
    req = urllib.request.Request(
        f"https://api.github.com/app/installations/{installation_id}/access_tokens",
        method="POST",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {jwt}"
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())['token']


def env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        sys.exit(f"Error: {name} environment variable not set")
    return value


def main():
    jwt = create_jwt(
        app_id=env('COCOTEC_BOT_APP_ID'),
        project=env('GCP_KMS_PROJECT'),
        location=env('GCP_KMS_LOCATION'),
        keyring=env('GCP_KMS_KEYRING'),
        key=env('GCP_KMS_KEY'),
        version=env('GCP_KMS_KEY_VERSION'),
    )
    print(get_installation_token(jwt, env('COCOTEC_BOT_INSTALLATION_ID')))


if __name__ == '__main__':
    main()
