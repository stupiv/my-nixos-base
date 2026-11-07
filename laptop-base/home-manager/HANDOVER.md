# HANDOVER — `laptop-base/home-manager/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix` in the
> authoring sandbox).

## What this directory is for

The **user profile** — everything that belongs to the human rather than the machine: terminal emulator, browser,
clipboard, audio presets, flatpak, XDG dirs, packages. These are **home-manager** modules (they see `pkgs`, `config`,
`lib`, `inputs`), imported from `laptop-base/home-manager.nix` via `home-manager.users.<admin>.imports`.

```nix
# laptop-base/home-manager/default.nix
imports = [
  ../common                       ← shared with the NixOS side, keep it dual-safe
  ./activitywatch.nix ./alacritty.nix ./clipboard.nix
  # ./default.nix
  ./easyeffects.nix ./flatpak.nix ./packages.nix ./xdg.nix ./zen-browser.nix
];
```

`unmaintained/` is **not** imported — see [`unmaintained/HANDOVER.md`](unmaintained/HANDOVER.md).

## Files

| File | What it does | Enabled by default? |
| --- | --- | --- |
| `alacritty.nix` | Dracula-ish colour scheme, `mkDefault true` | yes |
| `clipboard.nix` | `services.wl-clip-persist` + `services.copyq` (`forceXWayland = false`) | yes |
| `flatpak.nix` | imports `inputs.nix-flatpak.homeManagerModules.nix-flatpak`; auto-update `*-05,11-*`, `home.packages` gains `flatpak` | yes (`mkDefault true`) |
| `xdg.nix` | `xdg.enable`, `autostart`, `mimeApps`, `userDirs` — **documents/music/pictures/videos all = Downloads** | yes |
| `packages.nix` | `services.syncthing`; `xdg.mimeApps.defaultApplicationPackages` = onlyoffice, qview, mpv, zed-editor; `home.packages` += pinta, flameshot, resources, krecorder, cosmic-store | yes |
| `activitywatch.nix` | ActivityWatch from the upstream **AppImage**, extracted and patched; watcher `awatcher` from `pkgs-2611` | **yes — and it is broken, see below** |
| `easyeffects.nix` | PipeWire preset with autogain+limiter (output) and speex AGC/denoise/dereverb (input) | no (`myOpt.easyeffects.enable = false`) |
| `zen-browser.nix` | Zen browser via `inputs.zen-browser-flake`, `nixGL`, sets default browser, optional autostart | no (`myOpt.zen-browser.enable = false`) |

Options declared here: `myOpt.easyeffects.enable`, `myOpt.zen-browser.{enable,autoStart,setAsDefaultBrowser}`.

## The two heavy hitters

### `activitywatch.nix` — an AppImage turned into a package

```
fetchurl (activitywatch-linux-x86_64.AppImage, sha256-k9I2PSw…)
  → appimageTools.extract, then delete everything except aw-server-rust
  → runCommandLocal with autoPatchelfHook + glibc + libstdc++
  → services.activitywatch.package = aw-server, watchers.awatcher.package = pkgs-2611.awatcher
```

Also retargets the `systemd.user.targets.activitywatch` unit to `graphical-session.target` (so it does not start before
a session exists). Pinned version: `0.14.0b8`.

> **G4 — this file cannot evaluate as committed.** `inherit (pkgs) pkgs-2611;` requires an overlay that defines
> `pkgs.pkgs-2611`, and the only candidate ([`../common/nixpkgs-overlays.nix`](../common/HANDOVER.md)) is an empty stub.
> Since this module is imported *unconditionally*, the whole laptop home-manager profile depends on the host config
> providing that attribute. Fix at the source (`common/nixpkgs-overlays.nix`), not here.

Note the upstream AppImage is `x86_64` only — this file is not portable to `aarch64-linux`, despite the flake
advertising that system.

### `easyeffects.nix` — a preset, not a service knob

```nix
services.easyeffects = {
  enable = mkDefault true;
  package = mkDefault pkgs-2605.easyeffects;   # ← same G4 problem, but only when enabled
  preset  = "my-default-preset";
  extraPresets."my-default-preset" = { output = …; input = …; };
};
```

The interesting design choice: the preset keeps `autogain#0` + `limiter#0` **empty** (i.e. defaults) on the output side
and enables speex AGC/denoise/dereverb on the input side, which is a "make any microphone usable" preset. It needs
`programs.dconf.enable` from [`../../laptop-base/sound.nix`](../sound.nix), which is why that file sets it.

## Cross-cutting notes

- **`xdg.userDirs` maps everything to Downloads** (documents, music, pictures, videos). Deliberate: one folder, no
  decision fatigue. It also means `rclone-automount`'s default mount point (`<home>/<remote>`) and
  `hermes-agent`'s default `workingDirectory` (`xdg.userDirs.download`) both land in the same tree.
- **`packages.nix` builds `home.packages` from `xdg.mimeApps.defaultApplicationPackages`**, so that list is not just
  MIME defaults — it is the install list. Adding an app there installs *and* registers it.
- `mkFlatpakPath` is defined in `packages.nix` and **never used**, and `services.flatpak.packages` is empty; the flatpak
  plumbing is ready but unused.
- `xdg.autostart.entries` appears in both `packages.nix` (empty list) and `zen-browser.nix` (`optional autoStart …`).
  Two `xdg.autostart.entries` definitions mean **list concatenation** in home-manager, not override — so the empty list
  is harmless, but do not "clean up" the empty list expecting a different result.
- `clipboard.nix` uses `copyq` with `forceXWayland = false`, i.e. it wants a native Wayland Qt build; that depends on
  the Qt platform being Wayland-capable in the pinned nixpkgs.
- There is **no git/ssh/gpg/editor configuration** in this profile — `EDITOR` is set system-wide by
  [`../../nixos-base/terminal/micro.nix`](../../nixos-base/terminal/HANDOVER.md), and `programs.fish` comes from the
  system layer. If you expect `programs.git` here, it is simply absent.

## How to extend

- New GUI app → `packages.nix` (`home.packages`), or a new module if it needs services/options.
- New toggle → declare `options.myOpt.<thing>.enable = mkOption { type = types.bool; default = false; }` and gate the
  config with `mkIf`, matching `zen-browser.nix` / `easyeffects.nix`.
- Anything that needs a system package must be handled on the NixOS side, not here — home-manager cannot install system
  services.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — the NixOS modules feeding this profile (`sound.nix`, `home-manager.nix`)
- [`../common/HANDOVER.md`](../common/HANDOVER.md) — the `pkgs-2605`/`pkgs-2611` gap (**G4**)
- [`../../HANDOVER.md`](../../HANDOVER.md) — §7 global issues
- [`unmaintained/HANDOVER.md`](unmaintained/HANDOVER.md) — `hermes-agent.nix`
