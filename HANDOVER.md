1. This repository provides reusable NixOS modules rather than a complete host configuration.
    1. These notes describe an unbuilt source snapshot from 2026-11-07.
        1. The original snapshot used branch `arena/a7026f5a-my-nixos-base` at commit `66ded62`.
        2. The bullet-list revision used branch `arena/056af839-my-nixos-base` at commit `c103788` without rechecking claims.
        3. The authoring sandbox lacked Nix and access to `cache.nixos.org`, so runtime claims remain unverified.
        4. Items marked **⚠ verify** require further investigation.
    2. The flake exports the laptop and VPS module flavours.
        1. `flake.nixosModules.laptop-base` imports the shared system, desktop, hardware, and home-manager layers.
        2. `flake.nixosModules.vps-base` imports `../myPkgs` and `../nixos-base`.
        3. Downstream hosts supply mandatory options, hardware configuration, and installation modules.
        4. Application workloads are opt-in through `myOpt.*` instances.
        5. Unix sockets, isolated network namespaces, and socket activation connect most workloads.
        6. Sleep-on-idle freezes idle service slices rather than stopping their containers.
    3. The directory handovers describe each layer.
        1. [`nixos-base/`](nixos-base/HANDOVER.md) provides shared identity, SSH, DNS, boot, terminal, and service configuration.
        2. [`laptop-base/`](laptop-base/HANDOVER.md) adds desktop environments, hardware settings, and home-manager.
        3. [`vps-base/`](vps-base/HANDOVER.md) provides the minimal server entry point.
        4. [`install/`](install/HANDOVER.md) provides partitioning, hardware configuration, and deliberate installation reminders.
        5. [`myLib/`](myLib/HANDOVER.md) exposes helper functions through `pkgs.myLib`.
        6. [`myPkgs/`](myPkgs/HANDOVER.md) exposes OCI image tags through `pkgs.myPkgs`.
        7. Neither exported module imports `install/` automatically.
        8. Repeated imports of `myLib` and `myPkgs` are deduplicated by the module system.
    4. `flake.nix` and `flake.lock` define the inputs and pins.
        1. Default `nixpkgs` follows `nixpkgs-2605`, pinned to revision `7dcdd87` for NixOS 26.05.
        2. `nixpkgs-2611` pins unstable revision `3ec6363` but does not populate a secondary package scope.
        3. Home-manager follows `nixpkgs-2605` and tracks `release-26.05`.
        4. `hercules-ci/flake-parts` declares `x86_64-linux` and `aarch64-linux` systems.
        5. `Mic92/sops-nix` supplies system secret management.
        6. `nix-index-database` follows `nixpkgs` and supplies `comma`.
        7. `nix-community/disko` supplies partitioning for `install/disko-config.nix`.
        8. `gmodena/nix-flatpak?ref=latest` supplies the home-manager Flatpak module.
        9. `0xc000022070/zen-browser-flake` supplies Zen with nixGL support.
        10. `NixOS/nixos-hardware` is reserved for the unfinished installation module.
        11. Non-flake input `sjhgvr/oisd` supplies the pinned DNS blocklist.
        12. `NousResearch/hermes-agent/v0.21.7` supplies system and parked desktop agent modules.
        13. Hermes inputs intentionally avoid `follows` to preserve binary-cache compatibility.
        14. The snapshot has no CI, README, formatter configuration, or populated `.gitignore`.
        15. **⚠ verify** the expected formatter before replacing the hand-maintained, Alejandra-like formatting.
    5. Preserve the repository's module conventions.
        1. Keep commented self-import and dormant-directory markers such as `# ./default.nix`, `# ./defaut.nix`, and `# ./unmaintained`.
        2. Model services as `attrsOf` instance submodules filtered by `cfg.enable`.
        3. Top-level feature toggles usually default to `false`, while service-instance toggles usually default to `true`.
        4. Prefer `mkDefault` for host-overridable values and reserve `mkForce` for enforced policy.
        5. Name sops secrets `<instance>/<purpose>` and provision their values in the consumer's sops file.
        6. Treat `types.anything` pass-throughs as weakly checked configuration.
        7. Treat instance names as persistent identifiers because they determine units, sockets, slices, secrets, and state paths.
    6. Consumers must supply host-specific values.
        1. Set `myOpt.admin.username`, `myOpt.admin.hashedPassword`, and `myOpt.admin.authorizedKeys` explicitly.
        2. Generate password hashes with `mkpasswd`.
        3. Set `myOpt.openssh.port` whenever SSH is enabled.
        4. Set `myOpt.ipv6.public-address`, using `null` when static IPv6 is unwanted.
        5. The laptop layer supplies `myOpt.ipv6.public-address = null`.
        6. Set `myOpt.dnscrypt.ipv6.disable` for DNS filtering and Cloudflared transport selection.
        7. Set `system.stateVersion` in the host configuration.
        8. Set `myOpt.disk.id` and `myOpt.disk.device` when using disko.
        9. Supply `nixpkgs.hostPlatform`, `networking.hostName`, and workload-specific options downstream.
    7. The installation flow is inferred and requires verification.
        1. Partition with disko using a GPT BIOS partition, a 500 MiB ESP, and compressed btrfs `@root` and `@nix` subvolumes.
        2. Generate `install/facter.json` with `nixos-anywhere --generate-hardware-config nixos-facter ./facter.json`.
        3. Provision the age key at `/var/lib/sops-nix/key.txt` before removing the reminder import.
        4. Complete `install/nixos-hardware.nix` with the matching hardware module.
        5. Deploy the downstream host with `nixos-rebuild switch --flake .#<host>` or `nixos-anywhere`.
    8. Known issues retain their original identifiers.
        1. **G1** records resolved namespace-consumer mismatches in `camofox.nix`, `fastcrw.nix`, and `litellm.nix`.
            1. Old helpers expected `path`, `resolvConf`, and `unit`, while `netns.nix` exposes `nsPath` and `serviceUnit`.
            2. Compose modules now own namespace and cgroup wiring through `set-network-namespace` and `set-cgroup-parent`.
            3. Maintainer intent recorded on 2026-11-07 explicitly excludes DNS and direct Internet access from these namespaces.
        2. **G2** records the intentionally host-imported installation layer and its unfinished checklist.
            1. Keep the age-key and hardware `throw` reminders until each host satisfies them.
        3. **G3** records dormant directories outside the live import graph.
            1. Dormant code still requires valid syntax for formatters, analyzers, and editors.
        4. **G4** records missing `pkgs.pkgs-2611` and `pkgs.pkgs-2605` overlays.
            1. ActivityWatch requires `pkgs-2611` unconditionally, while enabled EasyEffects requires `pkgs-2605`.
            2. Define these scopes in `laptop-base/common/nixpkgs-overlays.nix` or provide them downstream.
        5. **G5** records SSH's `ports = [cfg.port]` with a `null` port default.
        6. **G6** records undeclared `cfg.n8n.serviceName` and `cfg.proxy-compose.hostname` reads in `n8n-compose.nix`.
        7. **G7** records TLP phone autosuspend exclusions, the `SAV` startup profile, and 75/80 percent battery thresholds.
        8. **G8** records the intentional `Asia/Ho_Chi_Minh` timezone and `en_DK.UTF-8` time locale.
        9. **G9** records 400 percent zram, forced empty `swapDevices`, and disabled disk writeback.
    9. Route maintenance work to the relevant layer.
        1. Add service modules under `nixos-base/services/` and register them in its `default.nix`.
        2. Model composed applications on `plausible-compose.nix` or `keycloak-compose.nix`.
        3. Edit `nixos-base/terminal/` for CLI packages and aliases.
        4. Edit `laptop-base/de.nix` or the desktop toggles to change desktop environments.
        5. Add GUI packages to `laptop-base/home-manager/packages.nix`.
        6. Update centralized image tags in `myPkgs/oci-img.nix` and pass them explicitly to service options.
        7. Add shared helpers under `myLib/` and register them in `myLib/default.nix`.
    10. Validate downstream hosts before relying on these notes.
        1. Read the shared and laptop `default.nix` import lists first.
        2. Treat the source tree as authoritative because the original snapshot had only squashed history.
        3. Resolve **G4** before evaluating a fresh laptop profile.
        4. Run Nix evaluation and builds against a configured downstream host rather than relying on module exports alone.
