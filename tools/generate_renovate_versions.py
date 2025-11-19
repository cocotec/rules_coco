#!/usr/bin/env python3

# Copyright 2025 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Generate a renovate_versions.json file for Renovate compatibility.

This script lists all rules_coco releases in the GCS bucket and generates
a JSON manifest that Renovate can use to detect new versions. This is helpful
for users who cannot access github.com but can access dl.cocotec.io.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# Pattern to extract version from tarball filename
VERSION_PATTERN = re.compile(
    r'^rules_coco_([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.]+)?)\.tar\.gz$')


def parse_version(filename: str) -> Optional[str]:
    """Extract version from a rules_coco tarball filename.

    Args:
        filename: The filename (e.g., 'rules_coco_0.1.3.tar.gz')

    Returns:
        The version string (e.g., '0.1.3') or None if no match
    """
    match = VERSION_PATTERN.match(filename)
    return match.group(1) if match else None


def compute_sha256_from_gcs(gcs_uri: str, temp_dir: Path) -> str:
    """Compute SHA256 digest of a file in GCS.

    Args:
        gcs_uri: Full GCS URI (e.g., 'gs://bucket/path/file.tar.gz')
        temp_dir: Temporary directory for downloading the file

    Returns:
        SHA256 hash as hexadecimal string
    """
    filename = gcs_uri.split('/')[-1]
    temp_file = temp_dir / filename

    subprocess.run(['gcloud', 'storage', 'cp', gcs_uri,
                    str(temp_file)],
                   capture_output=True,
                   text=True,
                   check=True)

    sha256_hash = hashlib.sha256()
    with open(temp_file, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256_hash.update(chunk)

    temp_file.unlink()

    return sha256_hash.hexdigest()


def process_release(obj: Dict, bucket_name: str,
                    temp_path: Path) -> Optional[Dict[str, str]]:
    """Process a single release object from GCS.

    Args:
        obj: GCS object metadata from gcloud storage ls --json
        bucket_name: GCS bucket name
        temp_path: Temporary directory for downloads

    Returns:
        Release dictionary or None if not a valid release
    """
    metadata = obj.get('metadata', {})
    name = metadata.get('name', '')
    if not name:
        return None

    # Extract filename and parse version
    filename = name.split('/')[-1]
    version = parse_version(filename)
    if not version:
        return None

    # Get timestamp from object metadata
    timestamp = metadata.get('timeCreated')

    # Compute SHA256 digest
    object_uri = f'gs://{bucket_name}/{name}'
    sha256_digest = compute_sha256_from_gcs(object_uri, temp_path)

    return {
        'version': version,
        'releaseTimestamp': timestamp,
        'changelogUrl':
        f'https://github.com/cocotec/rules_coco/releases/tag/{version}',
        'digest': sha256_digest
    }


def list_versions_from_gcs(bucket_name: str,
                           prefix: str,
                           max_workers: int = 8) -> List[Dict[str, str]]:
    """List all rules_coco releases from GCS bucket using gcloud CLI.

    Args:
        bucket_name: GCS bucket name (e.g., 'cocotec-downloads')
        prefix: Path prefix within bucket (e.g., 'rules_coco')
        max_workers: Maximum number of parallel workers for processing

    Returns:
        List of release dictionaries with version, timestamp, and URL
    """
    # Use gcloud CLI to list objects with JSON output
    gcs_uri = f'gs://{bucket_name}/{prefix}/'

    print(f"Listing versions from {gcs_uri}", flush=True)
    result = subprocess.run(['gcloud', 'storage', 'ls', '--json', gcs_uri],
                            capture_output=True,
                            text=True,
                            check=True)
    objects = json.loads(result.stdout)

    releases: List[Dict[str, str]] = []

    # Create temporary directory for downloading files
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        # Process releases in parallel
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            futures = {
                executor.submit(process_release, obj, bucket_name, temp_path):
                obj
                for obj in objects
            }

            # Collect results as they complete
            for future in as_completed(futures):
                try:
                    release = future.result()
                    if release:
                        releases.append(release)
                except Exception as e:
                    obj = futures[future]
                    name = obj.get('metadata', {}).get('name', 'unknown')
                    print(f"Error processing {name}: {e}", flush=True)

    # Sort by version (descending) - newest first
    releases.sort(
        key=lambda r: [int(x) for x in r['version'].split('-')[0].split('.')],
        reverse=True)

    return releases


def main():
    parser = argparse.ArgumentParser(
        description='Generate versions.json for Renovate compatibility')
    parser.add_argument('--bucket',
                        default='cocotec-downloads',
                        help='GCS bucket name (default: cocotec-downloads)')
    parser.add_argument('--prefix',
                        default='rules_coco',
                        help='Path prefix within bucket (default: rules_coco)')
    parser.add_argument('--out',
                        type=Path,
                        help='Output file path (default: stdout)')
    parser.add_argument('--pretty',
                        action='store_true',
                        help='Pretty-print JSON output')
    parser.add_argument(
        '--workers',
        type=int,
        default=min(os.cpu_count() or 4, 8),
        help=
        'Number of parallel workers for processing (default: min(cpu_count, 8))'
    )

    args = parser.parse_args()

    releases = list_versions_from_gcs(args.bucket, args.prefix, args.workers)
    print(f"Found {len(releases)} releases", flush=True)
    json_output = json.dumps(
        {
            'homepage': 'https://github.com/cocotec/rules_coco',
            'sourceUrl': 'https://github.com/cocotec/rules_coco',
            'releases': releases
        },
        indent=2 if args.pretty else None)
    if args.out:
        args.out.write_text(json_output)
        print(f"Wrote versions.json to {args.out}", flush=True)
    else:
        print(json_output)


if __name__ == '__main__':
    main()
