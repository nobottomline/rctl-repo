# rctl APT Repository

[![APT repository](https://img.shields.io/badge/APT-signed-147d64)](https://nobottomline.github.io/rctl-repo/)
[![Publish](https://github.com/nobottomline/rctl-repo/actions/workflows/pages.yml/badge.svg)](https://github.com/nobottomline/rctl-repo/actions/workflows/pages.yml)

This repository publishes the public LAN-only `rctl` package for Cydia,
Installer, Sileo, Zebra, and compatible Debian APT package managers.

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
- `rootless-releases.txt` is the explicit subset approved for rootless delivery.
  It is initially empty; listing both architectures in `repository.json` enables
  validation, not publication. `Release` advertises only architectures actually
  present in the generated package index.
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

## Rootless publication contract

One source URL serves separate `rctl_VERSION_iphoneos-arm.deb` (rootful) and
`rctl_VERSION_iphoneos-arm64.deb` (rootless) artifacts. Both keep package ID
`com.greatlove.rctl`; APT selects the architecture. Never rename a rootful binary
or combine the two layouts into one package.

Before adding a tag to `rootless-releases.txt`, the same immutable source release
must include the rootless DEB, its entry in `SHA256SUMS`, and an attested
`rctl-qualification_VERSION_iphoneos-arm64.json` report. Schema 4 requires
`product`, `tag`, `version`, `package: {name, architecture, sha256}` matching the
exact artifact, and boolean checks `rootless_runtime`, `package_manager_install`,
`package_manager_upgrade`, and `package_manager_recovery`, all true. All other
checks must also be true. Reports are evidence produced after physical-device
qualification, not values to fill in to unblock publication.

The generator validates the `/var/jb` payload, non-empty control client, rootless
maintainer-script prefix, ElleKit/firmware dependencies, and absence of private
relay configuration. Old rootful tags do not need rootless assets. Rootless does
not inherit the rootful bootstrap exemption for upgrade/recovery tests.

Run offline validation tests with `bash tests/packages.sh` (Bash, jq, dpkg-deb,
and sha256sum required). Production builds additionally verify immutable release
assets and sign the complete index through the protected workflow.

Source code, relay setup, security details, and contribution guidance live in
the [main rctl repository](https://github.com/nobottomline/rctl).

## License

Repository tooling and site sources are licensed under the
[Apache License 2.0](LICENSE). Published packages remain governed by the license
and third-party notices in the corresponding source release.
