# GitHub Actions Workflows

This directory contains the CI/CD workflows for building and publishing the Antigravity snap.

## build-and-publish.yml

Single workflow handling snap building and Snap Store publishing.

### Runners

`build-and-publish.yml` uses architecture-specific runners for build/test:
- `amd64` builds run on `ubuntu-24.04`
- `arm64` builds run on `ubuntu-24.04-arm`

`publish` and `detect-new-release.yml` run on `ubuntu-24.04`.

### Build Job

For each architecture (`amd64`, `arm64`), the workflow:

1. Checks out the selected ref (default: `github.ref`; manual runs use `refs/tags/<source_ref>`).
2. Builds the snap with `snapcore/action-build`.
3. Installs the produced snap with `--dangerous`.
4. Runs a smoke test:
   - Verifies binaries exist: `$SNAP/bin/antigravity` and `$SNAP/opt/antigravity/antigravity`.
5. Removes the test installation (cleanup always runs).
6. Uploads the built `.snap` as a workflow artifact.

### Publish Job

Depends on the build job and is gated by the trigger type.

**Trigger rules:**

| Trigger | Publish | Channel | Rules |
|---|---|---|---|
| `pull_request` | ✗ | — | Build and test only. |
| `push` to `main` | ✓ | `latest/edge` | Automatic publish to edge. |
| `push` tag `v*` | ✓ | `latest/stable` | Tag/version must match `snap/snapcraft.yaml` version. |
| `workflow_dispatch` | ✓ | Selected input | Manual republish from `source_ref` with chosen channel. |

**Stable publish validation:**

For any publish to `latest/stable`:
- Extract version from `snap/snapcraft.yaml` (regex: `version: '(.*)'`).
- Extract tag version (e.g., `v2.0.11` → `2.0.11`).
- Fail if versions don't match.

### GitHub Secrets

**Required:**

- `STORE_LOGIN`: output of `snapcraft export-login --snaps=antigravity --acls package_access,package_push,package_update,package_release -`.

Only used during `publish` job. Pull requests and build-only workflows do not need this secret.

### Manual Republish

Trigger via **Actions > Snap CI/CD > Run workflow**:

1. Enter `source_ref`: a release tag matching `v*` (for example, `v2.0.11`).
2. Select `channel`: choose the Snap Store channel (`latest/edge`, `latest/beta`, `latest/candidate`, `latest/stable`).
3. Click **Run workflow**.

**Constraints:**

- Manual publish requires `source_ref` to be a `v*` tag (applies to all channels).
- If targeting `latest/stable`, the tag version must also match `snap/snapcraft.yaml`.

### Action Versions

All actions are pinned to immutable commit SHAs:

- `actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10` (`v6.0.3`)
- `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (`v7.0.1`)
- `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (`v8.0.1`)
- `snapcore/action-build@3bdaa03e1ba6bf59a65f84a751d943d549a54e79` (`v1.3.0`)
- `snapcore/action-publish@214b86e5ca036ead1668c79afb81e550e6c54d40` (`v1.2.0`)

Updates should be reviewed before bumping SHAs.

### Concurrency

Build and publish operations for the same ref are serialized via concurrency group `snap-Snap CI/CD-<ref>`. In-progress runs are cancelled when a new run starts for the same ref.

## detect-new-release.yml

Daily monitor for **Antigravity Linux** releases with automated PR updates.

### Schedule

- Runs once per day on a cron schedule.
- Can also be triggered manually with `workflow_dispatch`.

### Behavior

1. Checks out the repository at branch `main`.
2. Reads `version` from `snap/snapcraft.yaml`.
3. Fetches `https://antigravity.google/releases` and discovers the hashed main JS bundle.
4. Extracts Antigravity Linux release URLs (not Antigravity IDE) using a full `major.minor.patch` triplet (`/<major>.<minor>.<patch>-build/linux-x64|linux-arm/Antigravity.tar.gz`).
5. Selects the latest release by semantic version and build number.
6. Runs `scripts/detect_new_release.sh` to detect the latest release and update `snap/snapcraft.yaml` (`version`, linux-x64 URL, linux-arm URL) when needed.
7. Pushes an automation branch and creates or updates a PR to `main`.

### GitHub Secrets and Permissions

- No repository secrets are required.
- The workflow needs:
  - `contents: write` (to push update branches)
  - `pull-requests: write` (to create/update PRs)

### Notes

- Branch naming: `automation/update-antigravity-<version>-<build>`.
- PR title format: `chore: update Antigravity to <version>`.
- Source monitored: `https://antigravity.google/releases`.
- Tarball URLs are allowlisted to `https://storage.googleapis.com/antigravity-public/antigravity-hub/.../linux-.../Antigravity.tar.gz`.
