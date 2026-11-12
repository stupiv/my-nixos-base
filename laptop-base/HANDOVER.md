1. `laptop-base/` exports the workstation flavour as `flake.nixosModules.laptop-base`.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. `default.nix` combines the shared system with desktop and hardware modules.
        1. `../nixos-base` supplies the shared system and service layer.
        2. [`common/`](common/HANDOVER.md) supplies shared overlays and cache settings.
        3. [`home-manager/`](home-manager/HANDOVER.md) supplies the user profile through `home-manager.nix`.
        4. [`unmaintained/`](unmaintained/HANDOVER.md) remains outside the import graph.
        5. Keep the commented `# ./home-manager` marker because the directory contains home-manager modules rather than NixOS modules.
    3. Desktop selection requires coordinated toggles.
        1. `de.nix` sets `myOpt.cosmic.enable = true`.
        2. `cosmic.nix` enables COSMIC and its greeter while excluding its editor, player, screenshot tool, and terminal.
        3. COSMIC sets `COSMIC_DATA_CONTROL_ENABLED = 1`.
        4. `plasma6.nix` optionally enables Plasma 6 and Wayland SDDM with a default-disabled toggle.
        5. No assertion prevents both desktops and conflicting greeters from being enabled.
        6. Switching to Plasma requires disabling COSMIC and ensuring exactly one display-manager provider.
    4. Hardware and desktop plumbing live in small modules.
        1. `appimage.nix` enables AppImage execution and binfmt using the shared `nix-ld` support.
        2. `bluetooth.nix` enables Bluetooth with firmware supplied by the shared layer.
        3. `firewall.nix` disables Caddy firewall opening for tunnel-based or local publication.
        4. `ipv6.nix` satisfies the shared required option with `myOpt.ipv6.public-address = null`.
        5. `naturalScrolling.nix` enables natural scrolling for all touchpads.
        6. `nixos_ozone_wl.nix` sets `NIXOS_OZONE_WL = 1` for Chromium and Electron Wayland support.
        7. `sound.nix` enables PipeWire, Pulse compatibility, and dconf for EasyEffects.
        8. `tlp.nix` enables shared TLP policy with 75/80 percent charging thresholds.
        9. Enabled TLP force-disables `power-profiles-daemon`, `thermald`, and `powertop`.
        10. `tmpfs.nix` places `/tmp` in RAM.
        11. `vi-ime.nix` enables fcitx5-bamboo with a Wayland frontend for Vietnamese Telex/VNI input.
        12. Disabling the IME overrides `mkDefault true`, while replacing its plain `fcitx5` type may require `mkForce`.
    5. Home-manager manages one admin user.
        1. `home-manager.nix` imports `inputs.home-manager.nixosModules.default` and the profile directory.
        2. The username and home directory come from `myOpt.admin`.
        3. `extraSpecialArgs = { inherit inputs; }` exposes flake inputs to profile modules.
        4. `backupFileExtension = "backup"` preserves replaced dotfiles as `*.backup`.
        5. `home.stateVersion = config.system.nixos.release` advances with the system pin rather than remaining fixed.
        6. Configure the admin options before evaluating the profile.
    6. Hosts must still supply machine configuration.
        1. Provide hardware configuration, hostname, platform, and `system.stateVersion` downstream.
        2. Import the [installation layer](../install/HANDOVER.md) when using disko and facter.
        3. Keep the mandatory IPv6 override even on laptops without static IPv6.
        4. Account for RAM-backed `/tmp`, 400 percent zram, and forced empty disk swap when testing memory pressure and hibernation.
        5. Resolve **G4** because the unconditionally imported ActivityWatch module requires undefined `pkgs.pkgs-2611`.
    7. Extend the user and desktop layers in their intended contexts.
        1. Prefer [`home-manager/packages.nix`](home-manager/packages.nix) for GUI packages.
        2. Retain Wayland compatibility for Ozone and the Vietnamese input frontend.
        3. The [shared-system handover](../nixos-base/HANDOVER.md) covers TLP assertions and common services.
        4. The [root handover](../HANDOVER.md) covers mandatory values and global issues.
