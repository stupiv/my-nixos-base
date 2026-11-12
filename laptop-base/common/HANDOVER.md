1. `laptop-base/common/` contains configuration shared by NixOS and home-manager.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. Both module systems import this directory separately.
        1. `laptop-base/default.nix` imports `./common` as a NixOS module.
        2. `laptop-base/home-manager/default.nix` imports `../common` as a home-manager module.
        3. Keep declarations valid in both contexts and place OS-only services elsewhere.
    3. `default.nix` imports `nixpkgs-overlays.nix`.
        1. The module adds `https://hermes-agent.cachix.org` as a substituter.
        2. Its trusted key is `hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU=`.
        3. Its overlay body is empty except for a commented `lib.extend` experiment referencing `final.pkgs-2611.lib`.
        4. The Hermes input avoids following nixpkgs inputs to retain cache-compatible derivation hashes.
    4. **G4** records missing secondary package scopes.
        1. `flake.nix` declares `nixpkgs-2605` and `nixpkgs-2611` without mapping them to `pkgs.pkgs-2605` and `pkgs.pkgs-2611`.
        2. [`activitywatch.nix`](../home-manager/activitywatch.nix) requires `pkgs-2611` unconditionally.
        3. Enabled EasyEffects requires `pkgs-2605`.
        4. This overlay is the intended place to import both package sets for the host platform.
        5. Adding those imports requires making `inputs` available in both module contexts.
    5. Cache settings require deliberate trust and merge decisions.
        1. NixOS merges these substituters with the shared `cache.nixos.org` and `nix-community.cachix.org` entries.
        2. The VPS path does not import this additional Hermes cache.
        3. Home-manager cache declarations do not replace system daemon configuration.
        4. Remove the substituter and its trusted key together if the cache is retired.
        5. Use `mkForce` only when intentionally replacing merged Nix settings.
        6. Do not assume deduplication crosses the separate NixOS and home-manager evaluations.
    6. Read the related handovers before extending this directory.
        1. The [laptop handover](../HANDOVER.md) explains both import paths.
        2. The [profile handover](../home-manager/HANDOVER.md) explains ActivityWatch and EasyEffects.
        3. The [root handover](../../HANDOVER.md) records inputs and **G4**.
