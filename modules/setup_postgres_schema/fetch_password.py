"""Fetch one versioned Key Vault secret using the projected workload identity."""

import json
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen


def main():
    secret_url = os.environ["PASSWORD_SECRET_URL"]
    parsed = urlsplit(secret_url)
    if (
        parsed.scheme != "https"
        or not (parsed.hostname or "").endswith(".vault.azure.net")
        or parsed.username
        or parsed.password
        or parsed.port not in (None, 443)
        or parsed.query
        or parsed.fragment
        or len(parsed.path.split("/")) != 4
        or not parsed.path.startswith("/secrets/")
        or not all(parsed.path.split("/")[2:])
    ):
        raise ValueError("Expected a versioned Azure Key Vault secret URL")

    token_url = (
        f"https://login.microsoftonline.com/{os.environ['AZURE_TENANT_ID']}"
        "/oauth2/v2.0/token"
    )
    # Azure federation and secret-scoped RBAC can lag successful ARM creation.
    deadline = time.monotonic() + 480
    while time.monotonic() < deadline:
        try:
            assertion = Path(os.environ["AZURE_FEDERATED_TOKEN_FILE"]).read_text().strip()
            request = Request(token_url, data=urlencode({
                "client_id": os.environ["AZURE_CLIENT_ID"],
                "grant_type": "client_credentials",
                "scope": "https://vault.azure.net/.default",
                "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                "client_assertion": assertion,
            }).encode())
            with urlopen(request, timeout=15) as response:
                token = json.load(response)["access_token"]
            request = Request(
                f"{secret_url}?api-version=7.4",
                headers={"Authorization": f"Bearer {token}"},
            )
            with urlopen(request, timeout=15) as response:
                password = json.load(response)["value"]
            if not isinstance(password, str) or not password:
                raise ValueError("Key Vault returned an empty or invalid password")
            fd = os.open("/credentials/password", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400)
            with os.fdopen(fd, "w") as output:
                output.write(password)
            return
        except HTTPError as error:
            status = error.code
            error.close()
            if status not in (400, 401, 403, 404, 408, 429) and status < 500:
                raise RuntimeError("Key Vault credential fetch was rejected") from None
        except (URLError, TimeoutError):
            pass
        # Never log response bodies, tokens, or secret values, even on failure.
        print("Waiting for workload identity and Key Vault access", file=sys.stderr, flush=True)
        time.sleep(5)
    raise RuntimeError("Timed out fetching the database password from Key Vault")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit("Database password fetch failed; check identity, federation, and secret access")
