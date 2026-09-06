import contextlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs

import fetch_password


class FetchPasswordTest(unittest.TestCase):
    def setUp(self):
        self.env = {
            "PASSWORD_SECRET_URL": "https://app.vault.azure.net/secrets/db-password/version",
            "AZURE_TENANT_ID": "tenant",
            "AZURE_CLIENT_ID": "client",
            "AZURE_FEDERATED_TOKEN_FILE": "/projected/token",
        }
        self.password = "secret-with-quote'[]{}"
        self.requests = []

    def response(self, request, timeout):
        self.requests.append(request)
        self.assertEqual(timeout, 15)
        if request.full_url.endswith("/token"):
            return io.BytesIO(json.dumps({"access_token": "access-token"}).encode())
        return io.BytesIO(json.dumps({"value": self.password}).encode())

    def test_exchange_and_exact_secret_version_without_logging_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "password"
            output = io.StringIO()
            real_open = os.open

            def open_password(path, flags, mode):
                self.assertEqual(path, "/credentials/password")
                return real_open(target, flags, mode)

            with (
                patch.dict(os.environ, self.env),
                patch.object(Path, "read_text", return_value="projected-token\n") as read,
                patch.object(fetch_password, "urlopen", side_effect=self.response),
                patch.object(os, "open", side_effect=open_password),
                contextlib.redirect_stdout(output),
                contextlib.redirect_stderr(output),
            ):
                fetch_password.main()
            read.assert_called_once_with()
            self.assertEqual(target.read_text(), self.password)
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o400)
            self.assertEqual(output.getvalue(), "")

        token_request, secret_request = self.requests
        self.assertEqual(token_request.full_url, "https://login.microsoftonline.com/tenant/oauth2/v2.0/token")
        form = parse_qs(token_request.data.decode())
        self.assertEqual(form["client_assertion"], ["projected-token"])
        self.assertEqual(form["client_id"], ["client"])
        self.assertEqual(form["grant_type"], ["client_credentials"])
        self.assertEqual(form["scope"], ["https://vault.azure.net/.default"])
        self.assertEqual(secret_request.full_url, self.env["PASSWORD_SECRET_URL"] + "?api-version=7.4")
        self.assertEqual(secret_request.get_header("Authorization"), "Bearer access-token")

    def test_retries_federation_rbac_and_transient_failures_without_response_body(self):
        for error in [
            HTTPError("url", status, "private error", {}, io.BytesIO(b"private response"))
            for status in (400, 401, 403, 404, 429, 500)
        ] + [URLError("private error"), TimeoutError("private error")]:
            with (
                self.subTest(error=type(error).__name__),
                patch.dict(os.environ, self.env),
                patch.object(Path, "read_text", return_value="projected-token"),
                patch.object(fetch_password, "urlopen", side_effect=error),
                patch.object(fetch_password.time, "monotonic", side_effect=[0, 0, 481]),
                patch.object(fetch_password.time, "sleep") as sleep,
                patch.object(os, "open") as write,
                contextlib.redirect_stderr(io.StringIO()) as output,
            ):
                with self.assertRaisesRegex(RuntimeError, "Timed out"):
                    fetch_password.main()
                sleep.assert_called_once_with(5)
                write.assert_not_called()
                self.assertNotIn("private", output.getvalue())

    def test_invalid_or_unversioned_url_never_receives_a_token(self):
        for url in (
            "http://app.vault.azure.net/secrets/pw/version",
            "https://example.com/secrets/pw/version",
            "https://app.vault.azure.net/secrets/pw",
            "https://app.vault.azure.net/secrets/pw/",
            "https://app.vault.azure.net/secrets/pw/version?extra=true",
        ):
            with (
                self.subTest(url=url),
                patch.dict(os.environ, {**self.env, "PASSWORD_SECRET_URL": url}),
                patch.object(fetch_password, "urlopen") as request,
            ):
                with self.assertRaises(ValueError):
                    fetch_password.main()
                request.assert_not_called()

    def test_empty_password_is_not_written(self):
        self.password = ""
        with (
            patch.dict(os.environ, self.env),
            patch.object(Path, "read_text", return_value="projected-token"),
            patch.object(fetch_password, "urlopen", side_effect=self.response),
            patch.object(os, "open") as write,
        ):
            with self.assertRaises(ValueError):
                fetch_password.main()
            write.assert_not_called()


if __name__ == "__main__":
    unittest.main()
