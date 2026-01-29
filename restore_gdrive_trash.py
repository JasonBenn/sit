#!/usr/bin/env python3
"""
Restore Google Docs and Sheets from Google Drive trash.

Usage:
1. First, set up credentials at https://console.cloud.google.com/apis/credentials
   - Create OAuth 2.0 Client ID (Desktop app)
   - Download JSON and save as credentials.json in this directory

2. Run: python3 restore_gdrive_trash.py
"""

import json
import os
from pathlib import Path
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Scopes needed to modify Drive files
SCOPES = ['https://www.googleapis.com/auth/drive']

TRASH_DIR = Path.home() / "Library/CloudStorage/GoogleDrive-jasoncbenn@gmail.com/.Trash"
SCRIPT_DIR = Path(__file__).parent
CREDENTIALS_FILE = SCRIPT_DIR / "credentials.json"
TOKEN_FILE = SCRIPT_DIR / "token.json"


def get_credentials():
    """Get or refresh OAuth credentials."""
    creds = None

    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDENTIALS_FILE.exists():
                print(f"ERROR: No credentials.json found at {CREDENTIALS_FILE}")
                print("\nTo set up credentials:")
                print("1. Go to https://console.cloud.google.com/apis/credentials")
                print("2. Create OAuth 2.0 Client ID (Desktop app)")
                print("3. Download JSON and save as credentials.json in this directory")
                return None

            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES
            )
            creds = flow.run_local_server(port=0)

        # Save credentials for next run
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())

    return creds


def get_doc_ids_from_trash():
    """Parse all .gdoc and .gsheet files in trash to get doc IDs."""
    doc_ids = []

    for ext in ['*.gdoc', '*.gsheet']:
        for file_path in TRASH_DIR.glob(ext):
            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    doc_id = data.get('doc_id')
                    if doc_id:
                        doc_ids.append({
                            'id': doc_id,
                            'name': file_path.name,
                            'path': str(file_path)
                        })
            except (json.JSONDecodeError, KeyError, FileNotFoundError, OSError) as e:
                print(f"Warning: Could not parse {file_path.name}: {e}")

    return doc_ids


def restore_file(service, file_id, file_name):
    """Restore a file from trash by setting trashed=False."""
    try:
        # First check if file exists and is trashed
        file = service.files().get(fileId=file_id, fields='id, name, trashed').execute()

        if not file.get('trashed'):
            print(f"  SKIP (not in trash): {file_name}")
            return 'skipped'

        # Restore by setting trashed=False
        service.files().update(
            fileId=file_id,
            body={'trashed': False}
        ).execute()

        print(f"  RESTORED: {file_name}")
        return 'restored'

    except HttpError as e:
        if e.resp.status == 404:
            print(f"  NOT FOUND (may be permanently deleted): {file_name}")
            return 'not_found'
        else:
            print(f"  ERROR: {file_name} - {e}")
            return 'error'


def main():
    print("Google Drive Trash Restore Script")
    print("=" * 50)

    # Get credentials
    creds = get_credentials()
    if not creds:
        return

    # Build Drive API service
    service = build('drive', 'v3', credentials=creds)

    # Get all doc IDs from trash folder
    print(f"\nScanning {TRASH_DIR} for .gdoc and .gsheet files...")
    docs = get_doc_ids_from_trash()
    print(f"Found {len(docs)} Google Docs/Sheets files\n")

    if not docs:
        print("No files to restore.")
        return

    # Show preview
    print("Files to restore:")
    for i, doc in enumerate(docs[:10]):
        print(f"  {i+1}. {doc['name']}")
    if len(docs) > 10:
        print(f"  ... and {len(docs) - 10} more\n")

    # Confirm
    response = input(f"\nRestore all {len(docs)} files from trash? (y/n): ")
    if response.lower() != 'y':
        print("Aborted.")
        return

    # Restore files
    print("\nRestoring files...")
    results = {'restored': 0, 'skipped': 0, 'not_found': 0, 'error': 0}

    for i, doc in enumerate(docs):
        print(f"[{i+1}/{len(docs)}] {doc['name']}")
        result = restore_file(service, doc['id'], doc['name'])
        results[result] += 1

    # Summary
    print("\n" + "=" * 50)
    print("Summary:")
    print(f"  Restored:  {results['restored']}")
    print(f"  Skipped:   {results['skipped']} (not in trash)")
    print(f"  Not found: {results['not_found']} (permanently deleted)")
    print(f"  Errors:    {results['error']}")


if __name__ == '__main__':
    main()
