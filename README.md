# antigravity-snap

Snap package for [Google Antigravity](https://antigravity.google). 

Supports **amd64** and **arm64**.

## Installation

To install Antigravity run:

```sh
sudo snap install antigravity
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
sudo snap install --dangerous antigravity_*.snap
```

After sideloading, connect the required interfaces manually (these are auto-connected for Store-distributed snaps):

```sh
sudo snap connect antigravity:password-manager-service :password-manager-service
```

To cross-build for both architectures using Canonical's remote build infrastructure:

```sh
snapcraft remote-build --build-for amd64,arm64
```

See the [remote build documentation](https://snapcraft.io/docs/remote-build) for details.

## Interfaces

| Interface | Purpose |
|---|---|
| `audio-playback`, `audio-record` | Audio input/output |
| `camera` | Webcam access |
| `cups-control` | Printing support |
| `home` | Access to the user's home directory |
| `network`, `network-bind` | Internet access and local server binding |
| `opengl` | GPU-accelerated rendering |
| `password-manager-service` | Access to the desktop keyring service |
| `removable-media` | Access to external drives |
| `shared-memory` | Chromium inter-process shared memory (`private: true`) |
| `x11`, `wayland` | Display server integration |

## Technical notes

### LDAP / Active Directory users

On systems where users are resolved via LDAP or Active Directory (i.e. not present in `/etc/passwd`), the snap's `language_server` process uses [`libnss-wrapper`](https://cwrap.org/nss_wrapper.html) with a synthetic passwd entry generated at launch from `$USER`, `$HOME`, `id -u`, and `id -g`. This allows the Go runtime's `os/user.LookupId()` to resolve the current user without requiring host NSS access from within the snap sandbox.

### Chromium sandboxing

The Electron app runs with `--no-sandbox --no-zygote`. These flags are required under strict snap confinement because Chromium's built-in sandbox conflicts with AppArmor. The snap itself provides the security boundary.

## Upstream source

The application binary is downloaded from Google's distribution server at build time. See https://antigravity.google/download.
