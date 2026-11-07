- This is the handover for `nixos-base/terminal/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It defines the shell/CLI experience, applied **system-wide** through `environment.systemPackages`, `environment.shellAliases`, `programs.fish` and `users.defaultUserShell`.
    - There is no home-manager here, because that lives in `laptop-base/home-manager/`.
    - It is imported from `nixos-base/default.nix` as `./terminal`, so a VPS gets the same CLI as the laptop.

  - Files
    - `default.nix` is the import list and carries the `# ./default.nix` marker.
    - `fish.nix` sets `users.defaultUserShell = fish` and `programs.fish.enable`, and adds the interactive init.
    - `bat.nix` adds `bat` and steals the alias `cat = "bat -p"`.
    - `btop.nix` adds `btop` and steals the aliases `htop = btop` and `top = btop`.
    - `eza.nix` adds `eza` and steals the aliases `ls`, `ll` and `lt`.
    - `clear.nix` adds no package and steals the alias `clear = "clear && date"`.
    - `comma.nix` adds `programs.nix-index` plus `nix-index-database.comma`.
    - `micro.nix` adds `micro` and `wl-clipboard`, sets `EDITOR`, and sets `programs.nano.enable = false`.
    - `misc.nix` adds `tealdeer`, which provides `tldr`.
    - `yazi.nix` adds `yazi` and steals the alias `lf = yazi`.
    - `trash.nix` adds `trash-cli` plus a systemd timer.

  - `fish.nix` — the interactive init, explained
    - The greeting line is `set fish_greeting (uuidgen -r && date)`.
    - The timing hooks are `function stamp_start --on-event fish_preexec … set -g __cmd_started (date '+%T') …` and `function stamp_end   --on-event fish_postexec  … printf '[%s → %s] took %ss\n' … $CMD_DURATION/1000 …`.
    - The greeting is a **random UUID plus timestamp**, so every shell is identifiable in a scrollback.
    - Every command gets a `[start → end] took N.NNs` line via `CMD_DURATION`.
    - **⚠ verify:** `uuidgen` comes from `util-linux`, which is *not* added to `environment.systemPackages` here.
      - On NixOS `uuidgen` is usually absent from a plain user profile, in which case the greeting silently ends up empty and fish prints an error per shell.
      - If you touch this file, either add `pkgs.util-linux` to the packages or drop `uuidgen`.
    - Because `users.defaultUserShell = pkgs.fish`, this applies to every user including root, and there is no bash fallback configured in the repo.

  - Alias policy (important)
    - The aliases are **aggressive**, because `cat`, `ls`, `top`, `htop` and `clear` are all replaced system-wide.
    - Scripts are unaffected since `environment.shellAliases` only affects interactive shells, but **muscle memory and copy-pasted instructions are not**.
      - `cat` is now `bat -p` in plain mode with no decorations, chosen deliberately so `cat file | …` still behaves.
    - `clear && date` is a deliberate "what time is it" hook, and it breaks `clear -x`.
    - These live in `environment.shellAliases`, so they are exported for **bash and zsh as well as fish** and a user who prefers bash still gets them.

  - `trash.nix` — the non-obvious one
    - It is the only file here with options.
      - `myOpt.trash-empty.frequency` defaults to `"*-01,03,05,07,09,11-02"`, a systemd `OnCalendar` expression meaning odd months on the 2nd day.
      - `myOpt.trash-empty.age` defaults to `"56"` days and is passed straight to `trash-empty --all-users`.
    - It defines a `trash-empty.service` with `Type = "oneshot"` running `trash-empty -f --all-users <age>`.
    - It defines a matching `trash-empty.timer` with `Persistent = true` and `wantedBy = ["timers.target"]`.
    - Deleted files therefore survive roughly eight weeks and then vanish, system-wide for all users.
    - **There is no per-user trash separation**, and because `--all-users` needs root and the unit does not set `User=`, it runs as root.

  - Gotchas
    - `comma.nix` imports `inputs.nix-index-database.nixosModules.nix-index` and enables `programs.nix-index-database.comma`.
      - That makes `, <cmd>` run an arbitrary nixpkgs binary, which on a VPS is a remote-code convenience that some people consider a foot-gun.
    - `micro.nix` disables `nano` and sets `EDITOR` to micro's **absolute store path** via `getExe`, so `EDITOR` differs from machine to machine and tools that compare `EDITOR` to `"vim"` will not match.
    - `wl-clipboard` is installed here even though it is Wayland-only, which is harmless on a VPS but useless there.
    - `yazi.nix` aliases `lf`, which is a different file manager, and that is intentional.
    - `btop.nix` does **not** alias `btop` away, and `eza.nix` keeps `ls` sorted by directories first with no `--icons`, so the output is deliberately icon-free and safe over SSH and in screenshots.

  - How to extend
    - Add `./<tool>.nix` with `environment.systemPackages` plus aliases if warranted, and list it in `default.nix`.
    - Prefer `getExe pkgs.<tool>` over bare names in scripts.
    - Keep shell snippets quoted, because `systemd.enableStrictShellChecks` set in `nixos-base/shellcheck.nix` applies repo-wide.

  - See also
    - [`../../laptop-base/home-manager/HANDOVER.md`](../../laptop-base/home-manager/HANDOVER.md) covers the GUI/user side.
    - [`../HANDOVER.md`](../HANDOVER.md) covers `shellcheck.nix` and strict shell checks.
