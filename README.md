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

| Branch | Contents |
| --- | --- |
| `main` | `bin/profilesync`, `config/*.example`, `README.md` |
| `backup/<host>-<id>` | that machine's latest encrypted archive (in `data/`) |

The machine id comes from `/etc/machine-id`, so a branch stays tied to the machine
even if its hostname changes.

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
- `--mine` restores from the current machine's own branch.
- `--pick` opens a `whiptail` checklist to choose exactly what to restore
  (default when run in a terminal). `--all` restores everything.
- `--dry-run` previews; `--to <dir>` restores under an alternate root instead of `/`.
- `--yes` skips the confirmation prompt.

Restoring `/etc/*` entries prompts for `sudo` only when needed.

## Commands

| Command | Description |
| --- | --- |
| `init` | Create user config from templates |
| `status` | Show resolved paths that would be backed up |
| `backup [--push] [-m msg]` | Encrypt + commit to this machine's branch |
| `list` | List local archives in `data/` |
| `branches` | List `backup/*` branches on origin |
| `restore [REF] [--branch n\|--mine] [--pick\|--all] [--dry-run] [--to dir] [--yes]` | Decrypt + restore |

## Notes

- The passphrase is the only thing protecting your keys — pick a strong one and
  remember it; there is no recovery.
- `data/` is git-ignored on `main`; archives only ever live on `backup/*` branches.
