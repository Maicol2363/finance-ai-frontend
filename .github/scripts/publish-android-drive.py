"""Replace the QR's APK in place; never create files or change sharing.

Only fixed endpoint requests carry OAuth credentials. Public verification uses a
separate anonymous request. Errors deliberately exclude response bodies/tokens.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request

FILE_ID = "1z__jJblXcb8MC2PZvE1tJzy3Kkh2GFgs"
PUBLIC_URL = f"https://drive.usercontent.google.com/download?id={FILE_ID}&export=download&confirm=t"
API_URL = f"https://www.googleapis.com/drive/v3/files/{FILE_ID}"


def public_download(destination):
    with urllib.request.urlopen(PUBLIC_URL, timeout=120) as response:
        with Path(destination).open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
    with Path(destination).open("rb") as source:
        if source.read(4) != b"PK\x03\x04":
            raise ValueError("The public QR download did not return an APK ZIP")


def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def publish(apk, commit):
    # Standard Google authorized-user JSON, owned by an editor of this file.
    credentials = json.loads(os.environ["DRIVE_AUTHORIZED_USER_JSON"])
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "client_id": credentials["client_id"],
        "client_secret": credentials["client_secret"],
        "refresh_token": credentials["refresh_token"],
    }).encode()
    request = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    with urllib.request.urlopen(request, timeout=30) as response:
        access = json.load(response)["access_token"]
    headers = {"Authorization": f"Bearer {access}"}
    request = urllib.request.Request(API_URL + "?fields=id,mimeType,capabilities", headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        metadata = json.load(response)
    if metadata["id"] != FILE_ID or not metadata["capabilities"].get("canEdit"):
        raise ValueError("Drive identity cannot update the existing QR file")
    if metadata["mimeType"] != "application/vnd.android.package-archive":
        raise ValueError("QR target is no longer an APK")
    # A media PATCH preserves ID, name, parents, permissions and QR URL. Retrying
    # the same run overwrites this same file, rather than making a duplicate.
    upload = f"https://www.googleapis.com/upload/drive/v3/files/{FILE_ID}?uploadType=media&fields=id,sha256Checksum"
    request = urllib.request.Request(upload, data=Path(apk).read_bytes(), method="PATCH", headers={
        **headers, "Content-Type": "application/vnd.android.package-archive",
    })
    with urllib.request.urlopen(request, timeout=180) as response:
        result = json.load(response)
    expected = digest(apk)
    if result["id"] != FILE_ID or result.get("sha256Checksum") != expected:
        raise ValueError("Drive checksum differs from the signed CI APK")
    public = Path(apk).with_suffix(".public.apk")
    try:
        public_download(public)
        if digest(public) != expected:
            raise ValueError("Anonymous QR download differs from the signed CI APK")
    finally:
        public.unlink(missing_ok=True)
    report = {"commit": commit, "sha256": expected, "drive_file_id": FILE_ID, "qr_url": f"https://drive.google.com/file/d/{FILE_ID}/view?usp=drivesdk"}
    Path(apk).with_suffix(".release.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk")
    parser.add_argument("--download-only", action="store_true")
    parser.add_argument("--commit")
    args = parser.parse_args()
    try:
        if args.download_only:
            public_download(args.apk)
        else:
            if not args.commit or len(args.commit) != 40:
                raise ValueError("A full source commit is required")
            publish(args.apk, args.commit)
    except (KeyError, ValueError, OSError, urllib.error.URLError):
        print("APK publication failed: check release credentials, Drive edit access and public download/checksum. No credentials or server response are logged.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
