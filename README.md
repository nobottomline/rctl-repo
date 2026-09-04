# rctl APT Repository

[![APT repository](https://img.shields.io/badge/APT-signed-147d64)](https://nobottomline.github.io/rctl-repo/)
[![Publish](https://github.com/nobottomline/rctl-repo/actions/workflows/pages.yml/badge.svg)](https://github.com/nobottomline/rctl-repo/actions/workflows/pages.yml)

This repository publishes the public LAN-only `rctl` package for Cydia, Sileo,
Zebra, and compatible Debian APT package managers.

**[Open the repository and choose a package manager](https://nobottomline.github.io/rctl-repo/)**

Manual source URL:

```text
https://nobottomline.github.io/rctl-repo/
```

The package feed is generated only from explicitly approved immutable releases
of [`nobottomline/rctl`](https://github.com/nobottomline/rctl). It never builds a
package and rejects personalized relay packages, relay configuration, and data
resembling enrollment credentials.

## Scope

This feed is exclusively for the ordinary public package that exposes rctl on a
trusted local network. A personalized relay package is created privately by the
self-hosted VPS wizard and must never be uploaded here.

The current package is qualified on iPadOS 14.4 with rootful unc0ver and
Substitute. Rootless and newer iOS configurations are not advertised as
supported until their physical-device qualification passes in the source
project.

## Publication model

- `releases.txt` is the append-only ledger of approved source release tags.
- `scripts/build-repository.sh` verifies each release, package, checksum,
  attestation, qualification report, and public-package boundary.
- The generator produces compressed APT indexes, web and native depictions, and
  signed `InRelease`/`Release.gpg` metadata.
- `.github/workflows/pages.yml` deploys the generated tree as a GitHub Pages
  artifact. Generated `.deb` files and indexes are not committed to Git.
- Tags after the bootstrap release require physical package-manager upgrade and
  recovery checks in the source qualification report.

The OpenPGP private key is available only to the protected
`apt-repository-signing` GitHub environment and the maintainer's offline backup.
The generated feed publishes the public key and its fingerprint.

Source code, relay setup, security details, and contribution guidance live in
the [main rctl repository](https://github.com/nobottomline/rctl).

## License

Repository tooling and site sources are licensed under the
[Apache License 2.0](LICENSE). Published packages remain governed by the license
and third-party notices in the corresponding source release.
