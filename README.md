# rctl APT Repository

This repository publishes the public, LAN-only `rctl` package for Cydia,
Sileo, Zebra, and other APT-compatible jailbreak package managers.

Add this source:

```text
https://nobottomline.github.io/rctl-repo/
```

The package feed is generated only from explicitly approved, immutable releases
of [`nobottomline/rctl`](https://github.com/nobottomline/rctl). It never builds a
package and never accepts personalized relay packages, relay configuration, or
device credentials.

## Publication model

- `releases.txt` is the append-only ledger of source release tags approved for
  publication.
- `scripts/build-repository.sh` downloads and verifies every listed release,
  generates the APT indexes, and signs the repository metadata.
- `.github/workflows/pages.yml` publishes the generated tree as a GitHub Pages
  artifact. Generated packages and indexes are not committed to Git history.
- Tags after the bootstrap release must carry package-manager upgrade and
  recovery checks in the source qualification report.

The OpenPGP private key is stored only as the protected
`APT_REPOSITORY_SIGNING_KEY_B64` Actions secret. The public key is exported into
the generated repository.

