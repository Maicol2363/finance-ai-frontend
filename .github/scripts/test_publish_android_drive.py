"""Offline release contract checks; no credentials or network needed."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("publisher", Path(__file__).with_name("publish-android-drive.py"))
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublicationTests(unittest.TestCase):
    def exercise(self, *, corrupt_public=False, can_edit=True):
        payload = b"PK\x03\x04synthetic signed APK bytes"
        requests = []

        def respond(request, **kwargs):
            url = request if isinstance(request, str) else request.full_url
            requests.append(request)
            if url == publisher.PUBLIC_URL:
                return io.BytesIO(payload + (b"wrong" if corrupt_public else b""))
            if url == "https://oauth2.googleapis.com/token":
                data = {"access_token": "synthetic-token"}
            elif url.startswith(publisher.API_URL):
                data = {"id": publisher.FILE_ID, "mimeType": "application/vnd.android.package-archive", "capabilities": {"canEdit": can_edit}}
            else:
                self.assertEqual(request.get_method(), "PATCH")
                self.assertEqual(request.data, payload)
                self.assertIn(f"/files/{publisher.FILE_ID}?uploadType=media", url)
                data = {"id": publisher.FILE_ID, "sha256Checksum": hashlib.sha256(payload).hexdigest()}
            return io.BytesIO(json.dumps(data).encode())

        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(payload)
            with patch.object(publisher.urllib.request, "urlopen", side_effect=respond), patch.dict(os.environ, {"DRIVE_AUTHORIZED_USER_JSON": json.dumps({"client_id": "test", "client_secret": "test", "refresh_token": "test"})}), contextlib.redirect_stdout(io.StringIO()):
                if corrupt_public or not can_edit:
                    with self.assertRaises(ValueError):
                        publisher.publish(apk, "a" * 40)
                    self.assertFalse(apk.with_suffix('.release.json').exists())
                else:
                    publisher.publish(apk, "a" * 40)
                    publisher.publish(apk, "a" * 40)
                    self.assertEqual(json.loads(apk.with_suffix('.release.json').read_text())["sha256"], hashlib.sha256(payload).hexdigest())
            self.assertFalse(apk.with_suffix('.public.apk').exists())
        patches = [request for request in requests if not isinstance(request, str) and request.get_method() == "PATCH"]
        self.assertEqual(len(patches), 0 if not can_edit else 1 if corrupt_public else 2)
        self.assertTrue(all(request.full_url == patches[0].full_url for request in patches))
        # The public request has no Authorization header or OAuth credential.
        self.assertTrue(all(isinstance(request, str) for request in requests if (request if isinstance(request, str) else request.full_url) == publisher.PUBLIC_URL))

    def test_retry_updates_same_file_and_verifies_public_sha(self):
        self.exercise()

    def test_public_checksum_mismatch_does_not_report_success(self):
        self.exercise(corrupt_public=True)

    def test_non_editor_cannot_publish(self):
        self.exercise(can_edit=False)


if __name__ == "__main__":
    unittest.main()
