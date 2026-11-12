1. `laptop-base/home-manager/` defines the admin user's desktop profile.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. `home-manager.nix` imports this directory with `pkgs`, `config`, `lib`, and `inputs`.
        1. `default.nix` imports `../common` and the active application modules.
        2. [`unmaintained/`](unmaintained/HANDOVER.md) remains excluded.
        3. Keep system services in NixOS modules rather than this user profile.
    3. Most profile modules are enabled by default.
        1. `alacritty.nix` configures Alacritty with a Dracula-like palette.
        2. `clipboard.nix` enables `wl-clip-persist` and CopyQ with `forceXWayland = false`.
        3. `flatpak.nix` imports `inputs.nix-flatpak`, installs Flatpak, and schedules updates with `*-05,11-*`.
        4. `xdg.nix` enables XDG directories, MIME handling, and autostart.
        5. Documents, music, pictures, and videos all point to Downloads.
        6. `packages.nix` enables Syncthing and installs the MIME-default packages OnlyOffice, qview, mpv, and Zed.
        7. Additional packages include Pinta, Flameshot, Resources, KRecorder, and COSMIC Store.
        8. The Flatpak package list is empty and `mkFlatpakPath` is unused.
    4. `activitywatch.nix` repackages upstream ActivityWatch `0.14.0b8`.
        1. It extracts the x86_64 AppImage and retains only `aw-server-rust`.
        2. It patches binaries with `autoPatchelfHook`, glibc, and libstdc++ through `runCommandLocal`.
        3. It configures `services.activitywatch.package` and selects `pkgs-2611.awatcher` as the watcher.
        4. Its user target follows `graphical-session.target`.
        5. **G4** prevents evaluation unless the host supplies the missing `pkgs.pkgs-2611` scope.
        6. Repair the shared overlay rather than duplicating package-set wiring here.
        7. The x86_64-only AppImage also limits portability to `aarch64-linux`.
    5. EasyEffects and Zen are optional profile features.
        1. `myOpt.easyeffects.enable` defaults to `false`.
        2. EasyEffects selects `pkgs-2605.easyeffects`, which also depends on the **G4** overlay repair.
        3. Preset `my-default-preset` uses default output autogain and limiter settings with Speex input AGC, denoising, and dereverberation.
        4. EasyEffects requires dconf already enabled by [`sound.nix`](../sound.nix).
        5. `myOpt.zen-browser.enable` defaults to `false`.
        6. Zen uses `inputs.zen-browser-flake` with nixGL and exposes `autoStart` and `setAsDefaultBrowser` options.
    6. Profile merges and defaults have visible effects.
        1. `xdg.mimeApps.defaultApplicationPackages` also determines installed packages.
        2. Autostart entry lists concatenate rather than replacing one another.
        3. Native Wayland CopyQ depends on compatible Qt support in the pinned nixpkgs.
        4. Hermes' parked working-directory default also points to Downloads.
        5. Git, SSH, GPG, and editor configuration are absent from this profile.
        6. The [terminal layer](../../nixos-base/terminal/HANDOVER.md) supplies fish and the system-wide Micro editor.
    7. Extend the profile with optional user-facing modules.
        1. Add GUI applications to `packages.nix` or create a module for application-specific services.
        2. Gate new `myOpt.<feature>.enable` options with `mkIf` and default them to `false`.
        3. The [laptop handover](../HANDOVER.md) describes the surrounding NixOS wiring.
        4. The [common handover](../common/HANDOVER.md) describes the missing package scopes.
        5. The [parked-profile handover](unmaintained/HANDOVER.md) describes Hermes.
