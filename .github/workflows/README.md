# GitHub Actions Workflows

This directory contains the CI/CD workflows for building and publishing the Antigravity snap.

## snap.yml

Unified workflow for building, testing, and continuously publishing the snap package to the `latest/edge` channel.

### Architecture Overview

- **Pull Requests**: Runs matrix build and smoke tests on `amd64` and `arm64`. No store publishing.
- **Pushes to `main`**: Runs matrix build and smoke tests across both architectures, then passes verified artifacts to `publish-edge` to release to `latest/edge`.
- **Channel Promotion**: Handled directly in the **Snap Store** (via [snapcraft.io](https://snapcraft.io/antigravity/releases) or local `snapcraft promote`). GitHub Actions has zero access to release directly to `beta`, `candidate`, or `stable`.

### Runners

- `amd64` builds run on `ubuntu-24.04`
- `arm64` builds run on `ubuntu-24.04-arm`
- Publishing and detection jobs run on `ubuntu-24.04`

### Trigger Rules

| Trigger | Job Executed | Target Channel | Description |
|---|---|---|---|
| `pull_request` | `build` | N/A | PR validation and smoke testing across `amd64` and `arm64`. No store publishing. |
| `push` to `main` | `build` &rarr; `publish-edge` | `latest/edge` | Builds, smoke tests, and publishes to `latest/edge` via `snapcore/action-publish`. |
| `workflow_dispatch` | `build` | N/A | Manual trigger to build and test the selected ref. |

### Build Job

For each architecture (`amd64`, `arm64`), the workflow:

1. Checks out the repository.
2. Builds the snap with `snapcore/action-build`.
3. Installs the produced classic-confinement snap with `--dangerous --classic`.
4. Runs a smoke test:
   - Verifies the packaged binary exists: `$SNAP/opt/antigravity/antigravity`.
5. Removes the test installation (cleanup always runs).
6. Uploads the built `.snap` as a workflow artifact when on `main`.

### Publish to Edge (`publish-edge`)

When a commit lands on `main`:

1. Waits until **both** `amd64` and `arm64` builds and smoke tests pass.
2. Downloads the artifacts produced by the `build` job.
3. Publishes both architectures to `latest/edge` using `snapcore/action-publish`.

### GitHub Secrets

**Required:**

- `STORE_LOGIN`: Scoped strictly to the `latest/edge` channel. Export using:
  ```bash
  snapcraft export-login --snaps=antigravity --channels=latest/edge \
    --acls=package_access,package_push,package_update,package_release -
  ```

Used exclusively during the `publish-edge` job. PR builds and matrix compilation runners have zero access to this secret.

### Action Versions

All actions are pinned to immutable commit SHAs:

- `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1` (`v7.0.1`)
- `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (`v7.0.1`)
- `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (`v8.0.1`)
- `snapcore/action-build@3bdaa03e1ba6bf59a65f84a751d943d549a54e79` (`v1.3.0`)
- `snapcore/action-publish@214b86e5ca036ead1668c79afb81e550e6c54d40` (`v1.2.0`)
- `canonical/has-signed-canonical-cla@v2` (used for CLA verification)

Updates should be reviewed before bumping SHAs.

## cla.yml

Verifies that pull request contributors have signed the Canonical Contributor License Agreement (CLA).

### Triggers

Runs on `pull_request_target` events for:
- `opened`
- `synchronize`
- `reopened`

### Behavior

1. Checks the pull request author against the Canonical CLA records.
2. Exempts bot accounts defined in `bot-accounts` (e.g. `dependabot[bot]`).
3. Reports compliance status back to GitHub.

## detect-new-release.yml

Daily monitor for **Antigravity Linux** releases with automated PR updates.

### Schedule

- Runs once per day on a cron schedule.
- Can also be triggered manually with `workflow_dispatch`.

### Behavior

1. Checks out the repository at branch `main`.
2. Reads `version` from `snap/snapcraft.yaml`.
3. Fetches release metadata from `https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases`.
4. Selects the latest release by semantic version and build number, then constructs Linux tarball URLs (`/<major>.<minor>.<patch>-build/linux-x64|linux-arm/Antigravity.tar.gz`).
5. Runs `scripts/detect_new_release.py` to detect the latest release and update `snap/snapcraft.yaml` (`version`, linux-x64 URL, linux-arm URL) when needed.
6. Pushes an automation branch and creates or updates a PR to `main`.

### GitHub Secrets and Permissions

- No repository secrets are required.
- The workflow needs:
  - `contents: write` (to push update branches)
  - `pull-requests: write` (to create/update PRs)
