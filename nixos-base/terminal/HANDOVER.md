1. `nixos-base/terminal/` defines the system-wide CLI profile for laptops and VPS hosts.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. `default.nix` imports packages, aliases, shell initialization, and trash cleanup.
        1. Keep its commented self-import marker.
        2. These modules use NixOS settings rather than home-manager.
    3. Individual modules select tools and aliases.
        1. `fish.nix` enables fish as the default user shell and installs interactive hooks.
        2. `bat.nix` installs Bat and aliases `cat` to `bat -p`.
        3. `btop.nix` installs btop and redirects `top` and `htop` to it.
        4. `eza.nix` installs eza and defines `ls`, `ll`, and `lt` aliases.
        5. Eza output groups directories first without icons.
        6. `clear.nix` aliases `clear` to `clear && date`.
        7. `comma.nix` imports nix-index-database and enables nix-index plus `comma`.
        8. `micro.nix` installs Micro and wl-clipboard, disables Nano, and sets `EDITOR` through `getExe`.
        9. `misc.nix` installs tealdeer for `tldr`.
        10. `yazi.nix` installs Yazi and aliases `lf` to it.
        11. `trash.nix` installs trash-cli and configures system-wide cleanup.
    4. Fish hooks add shell identification and command timing.
        1. The greeting runs `uuidgen -r && date`.
        2. Pre-execution and post-execution hooks print start time, end time, and elapsed seconds from `CMD_DURATION`.
        3. **⚠ verify** `uuidgen` availability because this module does not explicitly install `util-linux`.
        4. Add the missing package or remove the UUID command if the greeting fails.
        5. The default-shell setting also affects root unless overridden downstream.
    5. Interactive alias policy is intentionally broad.
        1. `cat`, `ls`, `top`, `htop`, `clear`, and `lf` differ from their conventional commands.
        2. Noninteractive scripts do not inherit ordinary interactive shell aliases.
        3. System aliases apply to supported interactive shells beyond fish.
        4. The `clear && date` alias does not preserve normal `clear -x` behavior.
        5. Micro's `EDITOR` value is an absolute store path rather than a conventional short editor name.
        6. wl-clipboard is installed even where no Wayland session exists.
        7. Comma can fetch and execute nixpkgs programs, so review that convenience for restricted VPS hosts.
    6. Trash cleanup is a root-level scheduled policy.
        1. `myOpt.trash-empty.frequency` defaults to `*-01,03,05,07,09,11-02` for the second day of odd-numbered months.
        2. `myOpt.trash-empty.age` defaults to 56 days.
        3. The oneshot service runs `trash-empty -f --all-users <age>`.
        4. Its timer is persistent and wanted by `timers.target`.
        5. Cleanup covers all users rather than a single home-manager profile.
        6. Files become eligible after 56 days but are removed only when the timer runs.
    7. Extend terminal tooling through small modules.
        1. Add a package-and-alias module and register it in `default.nix`.
        2. Prefer `getExe pkgs.<tool>` over bare executable names in scripts.
        3. Keep systemd scripts compatible with global strict shell checks.
    8. Read the related handovers for adjacent configuration.
        1. The [desktop-profile handover](../../laptop-base/home-manager/HANDOVER.md) covers user-facing GUI tools.
        2. The [shared-system handover](../HANDOVER.md) covers global shell-check policy.
