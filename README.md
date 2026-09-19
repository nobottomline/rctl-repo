# rctl APT Repository

**[Add rctl to your package manager](https://nobottomline.github.io/rctl-repo/)**

```text
https://nobottomline.github.io/rctl-repo/
```

One source serves Cydia, Sileo, Installer, Zebra and compatible APT clients.
The package is **rctl** (`com.greatlove.rctl`). Your package manager selects
the compatible build and offers subsequent updates:

| Jailbreak layout | Package architecture | Tested platform |
| --- | --- | --- |
| Rootful | `iphoneos-arm` | iPadOS 14.4, unc0ver / Substitute |
| Rootless | `iphoneos-arm64` | iPadOS 15.5, Dopamine / ElleKit |

These are separate DEBs, not a universal binary. RootHide is not covered.
The latest package is **0.4.4**. Public packages provide trusted-LAN access and
contain no relay configuration. Existing relay identity lives separately and is
preserved by updates. Personalized packages remain private.

## Publication

The source project owns runtime qualification and the stable release decision.
This repository distributes the **exact public artifacts**, without rebuilding:

1. `releases.txt` records stable tags; `rootless-releases.txt` records the subset
   with rootless artifacts. The source publisher updates both in one commit,
   after validating both packages. Older rootful-only releases remain available.
2. The generator requires a public, stable, immutable GitHub Release and
   verifies its release attestation and each asset against that attestation.
3. DEBs must match `SHA256SUMS`, package ID, version, architecture, dependencies
   and layout, contain a non-empty web client, and contain no relay configuration,
   enrollment credentials or symlinks.
4. The protected workflow generates compressed indexes and signs `InRelease`
   and `Release.gpg`. The signing-key fingerprint is pinned in this repository.
5. Isolated APT clients verify signatures, select and download both architectures,
   and simulate fresh installation and upgrade before Pages deployment. The same
   checks run against the public HTTPS feed afterward.

Distribution no longer requires separate runtime-report assets. The former
contract required a rootless report the source publisher did not emit, preventing
already published stable packages from reaching APT. Removing that duplicate
gate does not create runtime evidence or change source release checks.
Device qualification and remaining limits live in the
[source documentation](https://github.com/nobottomline/rctl/blob/main/docs/ROOTLESS-RELEASE.md).

The OpenPGP private key stays in the protected `apt-repository-signing`
environment and its offline backup. Public keys are published with the feed.
Generated DEBs and indexes are Pages artifacts, not Git-tracked files.

## Verification

Run `bash tests/release.sh` for offline package and release-boundary regression
tests. `bash scripts/verify-release.sh vMAJOR.MINOR.PATCH /tmp/new-output`
checks both public artifacts without a signing key or publication.

The full generator needs Bash 4+, GitHub CLI, jq, Debian APT/dpkg tooling,
GnuPG, curl and gzip/bzip2/xz/zstd. On Linux,
`bash tests/apt-client.sh https://nobottomline.github.io/rctl-repo/ 0.4.4`
uses disposable APT state and never installs packages or changes system sources.
Its install/upgrade checks are dependency-solver simulations, not physical
device lifecycle tests.

Source, relay setup and contribution guidance live in
[nobottomline/rctl](https://github.com/nobottomline/rctl).

## License

Repository tooling and site sources use [Apache License 2.0](LICENSE).
Published packages retain their source-release license and third-party notices.
