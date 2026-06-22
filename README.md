[![antigravity](https://snapcraft.io/antigravity/badge.svg)](https://snapcraft.io/antigravity)

# Antigravity snap

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

To install a locally built snap:

```sh
sudo snap install --dangerous --classic antigravity_*.snap
```

## Technical notes

This snap uses `confinement: classic`, so host integration and access controls follow classic snap behavior.

## Upstream source

The application binary is downloaded from Google's distribution server at build time. See https://antigravity.google/download.
