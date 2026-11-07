- This is the handover for `laptop-base/common/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds one file that is imported from **two different worlds**:
      - `laptop-base/default.nix` imports `./common` as a **NixOS** module.
      - `laptop-base/home-manager/default.nix` imports `../common` as a **home-manager** module.
    - Whatever lives here must therefore be valid in *both* module systems, which is why its only content is `nix.settings` and `nixpkgs.overlays`.
    - Both of those exist in NixOS and are at least tolerated by home-manager via its `nix`-awareness, whereas anything OS-specific here would break the home-manager import.

  - Files
    - `default.nix` contains `imports = [ ./nixpkgs-overlays.nix ];`.
    - `nixpkgs-overlays.nix` adds the `hermes-agent.cachix.org` substituter plus its public key, and an **empty** `nixpkgs.overlays` entry holding a commented-out experiment.

  - `nixpkgs-overlays.nix`, line by line
    - It sets `nix.settings.substituters = [ "https://hermes-agent.cachix.org" ];`.
    - It sets `nix.settings.trusted-public-keys = [ "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU=" ];`.
    - It declares `nixpkgs.overlays = [ (final: prev: { }) ];` whose only body is the commented block `# lib = prev.lib.extend (lfinal: lprev: { inherit (final.pkgs-2611.lib) customisation; });`.
    - Two things are worth flagging:
      - **This is the only place in the repo that adds a substituter beyond `nixos-base/nix.nix`**, which sets `cache.nixos.org` plus `nix-community.cachix.org`.
        - Because NixOS merges lists, the effective substituter set on the laptop is the union of both, while the VPS gets only the `nixos-base` pair.
        - The cachix cache matches the `hermes-agent` flake input (`NousResearch/hermes-agent`), whose comment in `flake.nix` says *"No inputs follows for cache to work"*, because following inputs would change the derivation hashes and miss the cache.
      - **The overlay is an empty function** and is a placeholder whose commented body is the abandoned attempt to extend `lib` with something from a second nixpkgs (`final.pkgs-2611.lib`).
        - That attribute does not exist anywhere in the repo (**G4**), which is exactly why this block is commented out and why [`../home-manager/activitywatch.nix`](../home-manager/activitywatch.nix) and `easyeffects.nix` cannot evaluate as written.

  - Why `pkgs-2611` / `pkgs-2605` matter here
    - `flake.nix` pins two nixpkgs revisions, `nixpkgs-2605` as the default and `nixpkgs-2611` for unstable packages, but **nothing maps them onto `pkgs.pkgs-2605` / `pkgs.pkgs-2611`**.
    - The natural home for that mapping is this file.
    - The mapping is not present and would probably look like `nixpkgs.overlays = [ (final: prev: { pkgs-2605 = import inputs.nixpkgs-2605 { inherit (prev.stdenv.hostPlatform) system; }; pkgs-2611 = import inputs.nixpkgs-2611 { inherit (prev.stdenv.hostPlatform) system; }; }) ];`.
    - That needs `inputs` threaded in, and the file currently takes no arguments at all, so adding it requires changing both consumers.

  - Gotchas
    - **Dual-import duplication** means `common` is imported by both `laptop-base` and `laptop-base/home-manager`, so the substituter list is declared twice on the laptop path.
      - Module deduplication makes it harmless, but anything *stateful* added here such as a `systemd` unit or a `home.file` will be defined from both contexts and may conflict.
    - **A home-manager module cannot set `nix.settings.substituters` meaningfully** because it is a system setting, so the import is tolerated rather than useful on that side, and this file should stay limited to things that are harmless in both.
    - **`trusted-public-keys` is security-relevant**, since a substituter key is permission to inject store paths.
      - `hermes-agent` is a third-party cache, so if the project is dropped, delete both lines rather than leaving an orphan key that quietly expands the trust root.
    - The `nix.settings` here is *merged* with `nixos-base/nix.nix`, which sets `experimental-features` and `trusted-users`, so do not add `substituters` here expecting to replace them and use `mkForce` if you really mean to.

  - How to extend
    - Keep it to declarations that are both idempotent and meaningful in NixOS and home-manager, such as overlays, `nix.settings` and `nixpkgs.config`.
    - For anything OS-only, create a sibling file and import it **only** from `laptop-base/default.nix`.

  - See also
    - [`../../HANDOVER.md`](../../HANDOVER.md) covers inputs and **G4**.
    - [`../HANDOVER.md`](../HANDOVER.md) covers how `common` is imported from both sides.
    - [`../home-manager/HANDOVER.md`](../home-manager/HANDOVER.md) covers the unconditional `activitywatch` import that trips G4.
