1. `nixos-base/` provides the shared system layer for both flake outputs.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. `default.nix` defines the active module inventory.
        1. It imports the `myLib` and `myPkgs` sibling scopes.
        2. It imports [`dnscrypt/`](dnscrypt/HANDOVER.md), [`services/`](services/HANDOVER.md), and [`terminal/`](terminal/HANDOVER.md).
        3. [`unmaintained/`](unmaintained/HANDOVER.md) has no entry point and remains excluded.
    3. Identity configuration determines administrative access.
        1. `admin.nix` declares `myOpt.admin.{username,hashedPassword,authorizedKeys,homeDirectory,uid,gid}`.
        2. It creates a normal user, a matching group, and wheel membership.
        3. The UID defaults to 1000 and the GID follows the UID.
        4. Non-null `authorizedKeys` defaults `myOpt.openssh.enable` to enabled.
        5. Enabled SSH restricts `AllowUsers` to the admin username.
        6. `openssh.nix` declares the SSH toggle, port, and optional Cloudflared tunnel fields.
        7. SSH disables root login, password authentication, and keyboard-interactive authentication while using `startWhenNeeded = true`.
        8. **G5** requires an explicit SSH port because `ports = [cfg.port]` otherwise contains `null`.
        9. An optional tunnel maps the configured hostname to `ssh://localhost:<port>`.
    4. Small modules define system-wide defaults and policy.
        1. `bootloader.nix` configures GRUB with `device = "nodev"`, EFI support, and removable-media installation.
        2. `caddy.nix` adds `nss` and `nss.tools` to enabled Caddy units for name lookups.
        3. `dirs.nix` declares `myOpt.homeDir` and `myOpt.downloadDir` directly under `myOpt`.
        4. `firmware.nix` enables redistributable firmware.
        5. `ipv6.nix` declares address, interface, and gateway options and applies static configuration only for a non-null address.
        6. `networkmanager.nix` enables NetworkManager and adds the admin to its group.
        7. `nix.nix` enables flakes and `nix-command`, trusts the admin, and configures the NixOS and nix-community caches.
        8. `nix-ld.nix` supports non-Nix binaries through `programs.nix-ld`.
        9. `no-coredump.nix` disables systemd-coredump and sets `kernel.core_pattern = "|/bin/false"`.
        10. `podman.nix` enables automatic pruning while service modules choose their OCI backend.
        11. `shellcheck.nix` enables strict systemd shell checks globally.
        12. `sops.nix` imports sops-nix and selects `/var/lib/sops-nix/key.txt`.
        13. `specialisation.nix` maps `myOpt.specialisation.<name>` to system specialisations with a forced `inside = true` marker.
        14. `time.nix` sets `Asia/Ho_Chi_Minh` and `LC_TIME = en_DK.UTF-8` under **G8**.
        15. `tlp.nix` supplies battery policy and incompatible-service assertions.
        16. `vmVariant.nix` gives both VM variants 8 GiB of RAM and four cores.
        17. `zramSwap.nix` selects 400 percent zram, forced empty `swapDevices`, and null writeback under **G9**.
    5. Cross-module contracts require care during changes.
        1. Configure required admin values even when features referencing them appear unused.
        2. NetworkManager, directory defaults, and rclone read admin identity without independent feature guards.
        3. Preserve existing top-level `myOpt` keys when adding declarations.
        4. Strict shell checks make invalid scripts build failures rather than runtime warnings.
        5. Re-enabling core dumps requires overriding both systemd-coredump and `kernel.core_pattern`.
        6. TLP asserts against and force-disables `power-profiles-daemon`, `thermald`, and `powertop`.
        7. **G7** records TLP phone autosuspend exclusions, disabled automatic profile switching, and the `SAV` startup profile.
        8. The nested `virtualisation` structure in `vmVariant.nix` is intentional for `build-vm`.
        9. Hosts may override unnecessary firmware to reduce VPS image size.
    6. Place new modules according to their scope.
        1. Add small cross-cutting defaults here and register them in `default.nix`.
        2. Put workloads under `services/` using its instance pattern.
        3. Keep unfinished modules outside the active import graph.
    7. Read the related handovers before host integration.
        1. The [root handover](../HANDOVER.md) lists mandatory values and global issues.
        2. The [services handover](services/HANDOVER.md) describes workloads and their primitives.
        3. The [installation handover](../install/HANDOVER.md) covers hardware, disko, and age-key provisioning.
