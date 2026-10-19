# Containerized Codex for bioinformatics

## Prerequisites
- Docker installed, current user in the `docker` group.
- A shared lab group GID for `/mnt/data` access — `docker_build.sh`/`export_alias.sh` assume GID `1001`. Edit the `--group-add 1001` line in `export_alias.sh` if it differs on this machine.

## Setup
```bash
git clone <repo-url> ~/codex/codex-setup/codex-main
cd ~/codex/codex-setup/codex-main
./docker_build.sh          # builds the codex-main image
./export_alias.sh          # installs the `codex` shell function into ~/.bashrc
source ~/.bashrc
```

The build script resolves its own location, so the repository can be cloned anywhere.

## Usage
From any project directory:
```bash
codex
```
Mounts `$(pwd)` at the same path in the container (workdir too), plus `~/codex/codex-home` as the persistent `/home/codex`. Host UID/GID are passed through so file ownership matches.

The launcher starts this development container with Docker's default seccomp profile disabled (`--security-opt seccomp=unconfined`). This is required for Codex's Bubblewrap sandbox to create its namespaces. Because it is a Docker *runtime* setting, after updating the setup run `./export_alias.sh` and `source ~/.bashrc` (or open a new shell); rebuilding the image alone does not apply it. Do not reuse this setting for an untrusted or production-facing container.

On the first run, follow Codex's sign-in flow. The resulting credentials and configuration persist in `~/codex/codex-home/.codex`. As an alternative for API-based access, export `OPENAI_API_KEY` in the host shell before running `codex`; the launcher forwards it to the container.

The initial R setup also installs several public GitHub packages. To avoid GitHub's unauthenticated API rate limit, create a short-lived fine-grained GitHub token and pass it only for that initial run:
```bash
read -rsp "GitHub PAT: " GITHUB_PAT; echo
export GITHUB_PAT
codex
unset GITHUB_PAT
```
The launcher forwards `GITHUB_PAT` to the container but does not save it in `codex-home` or `~/.bashrc`.

Existing Claude credentials are not reused: run Codex's sign-in flow once after the migration. `export_alias.sh` replaces an earlier managed Claude launcher block in `~/.bashrc` and creates the new persistent home directory.

To also mount a second host path read-write (e.g. shared data outside the project), pass it as the first argument:
```bash
codex /mnt/data/some/path
```

Other arguments are passed to Codex, so `codex --help` and `codex "review this script"` work as expected.

## Notes
- Container is stateless except for the bind-mounted workspace and `~/codex/codex-home`.
- First run installs R packages into `~/codex/codex-home/R` (persists after).
- Codex and its Code Mode host are installed together in the image at a pinned version. Update `CODEX_VERSION` in `dockerfile` and rebuild them together.
