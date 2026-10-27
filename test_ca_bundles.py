#!/usr/bin/env python3
"""Reject roots trusting compromised emSign chains in shipped trust stores."""

import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import zipfile


# GHSA-6q48-6c7w-9gw2, including the compromised cross-signed intermediates.
DISTRUSTED_ROOTS = {
    "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b": "emSign ECC Root CA - G3",
    "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4": "AAA Certificate Services",
}
BUNDLE_NAMES = {"cacert.pem", "ca-certificates.crt", "ca-bundle.crt", "cacerts.txt"}
SEARCH_ROOTS = (
    "/etc/ssl/certs",
    "/usr/lib/python3",
    "/usr/local/lib",
    "/opt/pipx",
    "/opt/browser-use",
    "/opt/az",
    "/usr/lib/google-cloud-sdk",
    "/usr/local/aws-cli",
)


def check_bundle(label, data):
    certificates = re.findall(
        rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", data, re.DOTALL
    )
    if not certificates:
        raise ValueError(f"No certificates in {label}")
    for certificate in certificates:
        der = ssl.PEM_cert_to_DER_cert(certificate.decode("ascii"))
        digest = hashlib.sha256(der).hexdigest()
        if digest in DISTRUSTED_ROOTS:
            raise ValueError(f"Distrusted {DISTRUSTED_ROOTS[digest]} remains in {label}")


def main():
    failures = []
    checked = 0
    for root in SEARCH_ROOTS:
        for directory, dirs, files in os.walk(root):
            dirs[:] = [name for name in dirs if name not in ("__pycache__", ".git")]
            for name in files:
                if name not in BUNDLE_NAMES:
                    continue
                path = Path(directory) / name
                try:
                    check_bundle(str(path), path.read_bytes())
                except ValueError as error:
                    failures.append(str(error))
                checked += 1

    # python -m venv seeds pip from these wheels, independently of system pip.
    wheels = list(Path("/usr/share/python-wheels").glob("pip-*.whl"))
    if not wheels:
        failures.append("Missing pip wheel for new Python virtual environments")
    for wheel in wheels:
        with zipfile.ZipFile(wheel) as archive:
            for name in archive.namelist():
                if name.endswith("/certifi/cacert.pem"):
                    try:
                        check_bundle(f"{wheel}:{name}", archive.read(name))
                    except ValueError as error:
                        failures.append(str(error))
                    checked += 1

    node_roots = json.loads(subprocess.check_output([
        "node", "-e",
        "process.stdout.write(JSON.stringify(require('tls').rootCertificates))",
    ]))
    for certificate in node_roots:
        try:
            check_bundle("Node.js bundled roots", certificate.encode("ascii"))
        except ValueError as error:
            failures.append(str(error))

    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Distrusted emSign chain roots absent from {checked} CA bundles and Node.js")


if __name__ == "__main__":
    main()
