# antigravity-snap

Snap package for [Google Antigravity](https://antigravity.google). 

Supports **amd64** and **arm64**.

## Installation

To install Antigravity run:

```sh
sudo snap install antigravity --classic
```

## Building

Install [Snapcraft](https://snapcraft.io/docs/snapcraft-overview) first:

```sh
sudo snap install snapcraft --classic
```

Then build locally (requires LXD or Multipass):

```sh
snapcraft
```

## GitHub Actions

The repository uses three workflows:

- `.github/workflows/build-and-publish.yml` builds and publishes the snap for both architectures.
- `.github/workflows/cla.yml` verifies that pull request contributors have signed the Canonical Contributor License Agreement (CLA).
- `.github/workflows/detect-new-release.yml` checks `https://antigravity.google/releases` daily and automatically opens/updates a pull request that bumps `snap/snapcraft.yaml` version and Linux tarball links when a newer release is detected.

See [`.github/workflows/README.md`](.github/workflows/README.md) for detailed workflow documentation, including secret setup, manual publish constraints, and action pinning.

Required repository secret: `STORE_LOGIN` (from `snapcraft export-login`).

To install a locally built snap:

```sh
sudo snap install --dangerous --classic antigravity_*.snap
```

To cross-build for both architectures using Canonical's remote build infrastructure:

```sh
snapcraft remote-build --build-for amd64,arm64
```

See the [remote build documentation](https://snapcraft.io/docs/remote-build) for details.

## Technical notes

This snap uses `confinement: classic`, so host integration and access controls follow classic snap behavior.

## Upstream source

The application binary is downloaded from Google's distribution server at build time. See https://antigravity.google/download.
