# GitHub Actions Workflows

This directory contains the CI/CD workflows for building and publishing the Antigravity snap.

## build-snap.yml

Workflow for build/test only.

### Runners

`build-snap.yml` uses architecture-specific runners for build/test:
- `amd64` builds run on `ubuntu-24.04`
- `arm64` builds run on `ubuntu-24.04-arm`

`publish-snap.yml`, `promote-snap.yml`, and `detect-new-release.yml` run on `ubuntu-24.04`.

### Build Job

For each architecture (`amd64`, `arm64`), the workflow:

1. Checks out the selected ref (default: `github.ref`; manual runs use `refs/tags/<source_ref>`).
2. Builds the snap with `snapcore/action-build`.
3. Installs the produced classic-confinement snap with `--dangerous --classic`.
4. Runs a smoke test:
   - Verifies the packaged binary exists: `$SNAP/opt/antigravity/antigravity`.
5. Removes the test installation (cleanup always runs).
6. Uploads the built `.snap` as a workflow artifact.

### Trigger rules for this workflow

| Trigger | Action | Rules |
|---|---|---|
| `pull_request` | Build and test | PR validation only. |
| `push` to `main` | Build and test | Produces artifacts consumed by `publish-snap.yml`. |
| `workflow_dispatch` | Build and test | Builds from a selected ref for manual validation. |

### GitHub Secrets

**Required:**

- `STORE_LOGIN`: output of `snapcraft export-login --snaps=antigravity --acls package_access,package_push,package_update,package_release -`.

Used during publish/promote jobs. Build-only workflows do not need this secret.

### Manual build

Trigger via **Actions > Snap Build CI > Run workflow**:

1. Enter `source_ref`: a git ref (branch, tag, or SHA).
2. Click **Run workflow**.

**Constraints:**

- Manual build requires a valid git ref.

### Concurrency

Build operations for the same ref are serialized via concurrency group `snap-build-Snap Build CI-<ref>`. In-progress runs are cancelled when a new run starts for the same ref.

## publish-snap.yml

Workflow dedicated to publishing edge snaps from `main` builds.

### Trigger rules

| Trigger | Action | Channel | Rules |
|---|---|---|---|
| `push` to `main` | Publish | `latest/edge` | Consumes artifacts from successful `build-snap.yml` for the same commit SHA. |

### Publish behavior

1. Resolves the matching successful build run for the same `main` commit SHA.
2. Downloads `amd64` and `arm64` snap artifacts from that run.
3. Publishes both artifacts to `latest/edge`.
4. Writes an edge publish marker artifact (`published-latest-edge-<sha>`) with source revisions per architecture.

### Concurrency

Publish operations for the same ref are serialized via concurrency group `snap-publish-Snap Publish-<ref>`. In-progress runs are cancelled when a new run starts for the same ref.

## promote-snap.yml

Workflow dedicated to channel promotion without rebuild.

### Trigger rules

| Trigger | Action | Channel | Rules |
|---|---|---|---|
| `push` tag `v*` | Promote | `latest/edge` -> `latest/stable` | Uses defaults, validates tag version, and promotes. |
| `workflow_dispatch` | Promote | Selected source -> selected target | Manual promotion from a `v*` tag via `source_ref`, with configurable `source_channel` and `target_channel`. |

### Promotion command

```sh
snapcraft release antigravity "<amd64-revision>,<arm64-revision>" <target_channel>
```

### Promotion validation

For any promotion run:
- Extract version from `snap/snapcraft.yaml` (regex: `version: '(.*)'`).
- Extract tag version (e.g., `v2.0.11` → `2.0.11`).
- Fail if versions don't match.
- Resolve the promoted tag to its commit SHA.
- Locate the corresponding source-channel publish marker artifact (`published-<source-channel-slug>-<sha>`) from a successful `publish-snap.yml` run on `main`; for manual runs this can be overridden with explicit expected revisions.
- Compare the currently published source-channel revisions (amd64/arm64) from the Snap Store channel map with the expected revisions.
- Fail promotion if any architecture revision differs.

### Manual promotion

Trigger via **Actions > Snap Stable Promote > Run workflow**:

1. Enter `source_ref`: a release tag matching `v*` (for example, `v2.0.11`).
2. Optionally set `source_channel` (default `latest/edge`) and `target_channel` (default `latest/stable`).
3. Optionally set `expected_source_revision_amd64` and/or `expected_source_revision_arm64` to override commit-matched defaults.
4. Click **Run workflow**.

### Concurrency

Promotions for the same ref are serialized via concurrency group `snap-promote-Snap Stable Promote-<ref>`. In-progress runs are cancelled when a new run starts for the same ref.

### Action Versions

All actions are pinned to immutable commit SHAs:

- `actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10` (`v6.0.3`)
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

Using `pull_request_target` ensures the workflow has appropriate permissions to set the commit status check even for pull requests submitted from external forks.

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
