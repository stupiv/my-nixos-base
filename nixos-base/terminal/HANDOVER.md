# HANDOVER — `nixos-base/terminal/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

The shell/CLI experience, applied **system-wide** (`environment.systemPackages`, `environment.shellAliases`,
`programs.fish`, `users.defaultUserShell`). There is no home-manager here — that lives in
`laptop-base/home-manager/`. Imported from `nixos-base/default.nix` (`./terminal`), so a VPS gets the same CLI as the
laptop.

## Files

| File | Adds | Aliases it steals |
| --- | --- | --- |
| `default.nix` | import list (`# ./default.nix` marker) | – |
| `fish.nix` | `users.defaultUserShell = fish`, `programs.fish.enable`, interactive init | – |
| `bat.nix` | `bat` | `cat = "bat -p"` |
| `btop.nix` | `btop` | `htop = btop`, `top = btop` |
| `eza.nix` | `eza` | `ls`, `ll`, `lt` |
| `clear.nix` | – | `clear = "clear && date"` |
| `comma.nix` | `programs.nix-index` + `nix-index-database.comma` | – |
| `micro.nix` | `micro`, `wl-clipboard`; `EDITOR`; `programs.nano.enable = false` | – |
| `misc.nix` | `tealdeer` (`tldr`) | – |
| `yazi.nix` | `yazi` | `lf = yazi` |
| `trash.nix` | `trash-cli` + a systemd timer | – |

## `fish.nix` — the interactive init, explained

```fish
set fish_greeting (uuidgen -r && date)
function stamp_start --on-event fish_preexec … set -g __cmd_started (date '+%T') …
function stamp_end   --on-event fish_postexec  … printf '[%s → %s] took %ss\n' … $CMD_DURATION/1000 …
```

- The greeting is a **random UUID + timestamp**, so every shell is identifiable in a scrollback.
- Every command gets a `[start → end] took N.NNs` line via `CMD_DURATION`.
- **⚠ verify:** `uuidgen` comes from `util-linux`, which is *not* added to `environment.systemPackages` here. On NixOS
  `uuidgen` is usually absent from a plain user profile, in which case the greeting silently ends up empty and fish
  prints an error per shell. If you touch this file, either add `pkgs.util-linux` to the packages or drop `uuidgen`.
- Because `users.defaultUserShell = pkgs.fish`, this applies to every user including root — there is no bash fallback
  configured in the repo.

## Alias policy (important)

The aliases are **aggressive**: `cat`, `ls`, `top`, `htop` and `clear` are all replaced system-wide. Consequences:

- Scripts are unaffected (`environment.shellAliases` only affects interactive shells), but **muscle memory and
  copy-pasted instructions are not.** `cat` is now `bat -p` (plain, no decorations) — chosen deliberately so
  `cat file | …` still behaves.
- `clear && date` is a deliberate "what time is it" hook; it breaks `clear -x`.
- These live in `environment.shellAliases`, i.e. they are exported for **bash and zsh as well as fish**, so a user who
  prefers bash still gets them.

## `trash.nix` — the non-obvious one

It is the only file here with options:

| Option | Default | Meaning |
| --- | --- | --- |
| `myOpt.trash-empty.frequency` | `"*-01,03,05,07,09,11-02"` | systemd `OnCalendar` — odd months, 2nd day |
| `myOpt.trash-empty.age` | `"56"` | days, passed straight to `trash-empty --all-users` |

It defines a `trash-empty.service` (`Type = "oneshot"`, `trash-empty -f --all-users <age>`) plus a matching
`trash-empty.timer` (`Persistent = true`, `wantedBy = ["timers.target"]`). So deleted files survive ~8 weeks and then
vanish — system-wide, all users. **There is no per-user trash separation**; `--all-users` needs root, and the unit does
not set `User=`, so it runs as root.

## Gotchas

- `comma.nix` imports `inputs.nix-index-database.nixosModules.nix-index` and enables `programs.nix-index-database.comma`.
  That makes `, <cmd>` run an arbitrary nixpkgs binary. On a VPS this is a remote-code convenience; some people consider
  it a foot-gun.
- `micro.nix` disables `nano` and sets `EDITOR` to micro's **absolute store path** (via `getExe`), so `EDITOR` differs
  from machine to machine. Tools that compare `EDITOR` to `"vim"` will not match.
- `wl-clipboard` is installed here even though it is Wayland-only; harmless on a VPS, useless there.
- `yazi.nix` aliases `lf`, which is a different file manager. Intentional.
- `btop.nix` does **not** alias `btop` away, and `eza.nix` keeps `ls` sorted by directories first — no `--icons`, i.e.
  the output is deliberately icon-free (safe over SSH and in screenshots).

## How to extend

Add `./<tool>.nix` with `environment.systemPackages` (+ aliases if warranted) and list it in `default.nix`. Prefer
`getExe pkgs.<tool>` over bare names in scripts; `systemd.enableStrictShellChecks` (set in `nixos-base/shellcheck.nix`)
applies repo-wide, so keep shell snippets quoted.

## See also

- [`../../laptop-base/home-manager/HANDOVER.md`](../../laptop-base/home-manager/HANDOVER.md) — the GUI/user side
- [`../HANDOVER.md`](../HANDOVER.md) — `shellcheck.nix` (strict shell checks)
