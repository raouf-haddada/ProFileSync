# ProFileSync

Encrypted, git-backed sync of your shell config, `/etc` files, scripts, and keys
— with one backup branch per machine.

- **Encryption:** GPG symmetric (AES-256). Nothing readable is ever pushed.
- **Compression:** `tar` + `xz`, plus a configurable exclude list.
- **Large files:** archives over 45 MB are auto-split into <50 MB chunks (GitHub-safe)
  and transparently re-joined on restore.
- **Per-machine branches:** `main` holds only this tool; each machine pushes its
  encrypted archives to `backup/<hostname>-<machine-id>`.

## Layout

| Repo / branch | Contents |
| --- | --- |
| tool repo · `main` | `bin/profilesync`, `config/*.example`, `README.md` |
| backup repo · `backup/<host>-<id>` | that machine's latest encrypted archive (in `data/`) |

The **backup repo can be the same repo** (backups on `backup/*` branches alongside
`main`) **or a completely separate repo** on any host — set it with
`--backup-remote` at install time. The machine id comes from `/etc/machine-id`, so
a branch stays tied to the machine even if its hostname changes.

## Setup

```sh
git clone git@github.com:raouf-haddada/ProFileSync.git
cd ProFileSync
./bin/profilesync init        # creates ~/.config/profilesync/{paths,excludes}.conf
$EDITOR ~/.config/profilesync/paths.conf
```

`paths.conf` lists what to back up (dotfiles, `~/.ssh`, scripts, curated `/etc`
entries, custom dirs). `excludes.conf` lists `tar` globs to skip (caches,
`node_modules`, blobs, …).

## Back up (on the source machine)

```sh
./bin/profilesync status      # preview what would be included
./bin/profilesync backup --push
```

This builds an encrypted archive, commits it to this machine's `backup/…` branch,
and pushes that branch. `main` is untouched. Omit `--push` to keep it local.

Set `PROFILESYNC_PASSPHRASE` to avoid the interactive prompt (e.g. in cron).

## Restore (on any machine)

```sh
git clone git@github.com:raouf-haddada/ProFileSync.git && cd ProFileSync
./bin/profilesync branches                       # see which machines have backups
./bin/profilesync restore --branch ubuntu-2f6a3d1349f9 --pick
```

- `--branch <name>` pulls the latest archive straight from that machine's branch
  (no checkout needed). `<name>` may omit the `backup/` prefix.
- `--remote <url>` fetches from an arbitrary **backup repo** (handy when the
  backups live in a different repo than the tool, and you've only cloned the
  tool). Defaults the branch to this machine's if `--branch` is omitted, e.g.:
  `profilesync restore --remote git@host:org/backups.git --branch ubuntu-2f6a3d1349f9`
- `--mine` restores from the current machine's own branch.
- `--pick` opens a `whiptail` checklist to choose exactly what to restore
  (default when run in a terminal). `--all` restores everything.
- `--dry-run` previews; `--to <dir>` restores under an alternate root instead of `/`.
- `--yes` skips the confirmation prompt.

Restoring `/etc/*` entries prompts for `sudo` only when needed.

## Autobackup as a service

Install a systemd timer that backs up unattended. Run as root:

```sh
sudo ./bin/profilesync install \
  --backup-remote git@github.com:raouf-haddada/profilesync-backups.git \
  --user raouf \
  --schedule daily \
  --extra-dir /home/raouf/workspace/env-vars
# prompts once for the backup passphrase (or set PROFILESYNC_PASSPHRASE)
```

The **backup repo** (`--backup-remote`) is where encrypted archives are pushed
as `backup/*` branches. It is **independent of this tool's source repo** — point
it at any repo on any host (a private backups repo is recommended). If omitted,
it defaults to the current clone's `origin`.

`install`:

1. Initializes a local work repo at `--repo-dir` (default
   `/var/lib/profilesync/repo`) with `origin` = the backup remote.
2. Installs the binary to `/usr/local/bin/profilesync`.
3. Seeds `/etc/profilesync.d/{paths,excludes}.conf` (from your `~/.config`
   config if present, else the bundled examples) so the service's path list
   does not depend on the backup repo's contents.
4. Writes `/etc/profilesync.conf` (mode 0600) — see
   [`config/profilesync.conf.example`](config/profilesync.conf.example).
5. Installs + enables `profilesync-backup.timer` (`daily` / `hourly` / `weekly`).

The config persists the **backup remote**, **SSH key**, **extra dirs**, the
backup **user**, and the **passphrase** (stored encrypted).

### How the passphrase is protected

On install, the passphrase is encrypted with **AES-256** using a key derived
from `sha256(<SSH private key file>)`. That SSH key is the same one used to reach
the git remote, so:

- The running service decrypts it unattended (the key is on disk).
- A leaked `/etc/profilesync.conf` **alone** never reveals the passphrase.
- On another machine, provisioning the **same SSH key** lets restore decrypt the
  passphrase with the identical algorithm — no passphrase re-entry needed.

Re-encode the passphrase anytime with `sudo profilesync set-passphrase`.

### Service management

```sh
sudo systemctl start profilesync-backup.service   # run a backup now
journalctl -u profilesync-backup.service          # logs
systemctl list-timers profilesync-backup.timer    # next run
sudo profilesync show-config                      # inspect conf (passphrase masked)
sudo profilesync uninstall [--purge]              # remove timer (+ conf & repo)
```

## Commands

| Command | Description |
| --- | --- |
| `init` | Create user config from templates |
| `status` | Show resolved paths that would be backed up |
| `backup [--push] [-m msg]` | Encrypt + commit to this machine's branch |
| `list` | List local archives in `data/` |
| `branches` | List `backup/*` branches on origin |
| `restore [REF] [--branch n\|--mine\|--remote url] [--pick\|--all] [--dry-run] [--to dir] [--yes]` | Decrypt + restore |
| `install [--backup-remote URL] [--user N] [--ssh-key P] [--schedule S] [--extra-dir D] [--repo-dir D]` | Set up the autobackup systemd timer (root) |
| `uninstall [--purge]` | Remove the timer/units (+ conf & repo with `--purge`) |
| `set-passphrase` | Re-encrypt the backup passphrase into the conf (root) |
| `show-config` | Print `/etc/profilesync.conf` (passphrase masked) |

## Notes

- The passphrase is the only thing protecting your keys — pick a strong one and
  remember it; there is no recovery.
- `data/` is git-ignored on `main`; archives only ever live on `backup/*` branches.
