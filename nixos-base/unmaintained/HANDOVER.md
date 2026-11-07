- This is the handover for `nixos-base/unmaintained/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds parked modules.
    - **There is no `default.nix` here and nothing imports the directory**, so it is fully outside the evaluation graph of both flake outputs.
    - Unlike `services/compose/unmaintained/`, which is excluded by a commented import, this one is excluded simply by not having an entry point, so if you ever add a `default.nix` everything inside becomes live at once.

  - Contents
    - `mesa-opencl.nix` is 25 lines of opt-in Rusticl/OpenCL that sets `hardware.graphics.extraPackages = [ mesa.opencl ]` plus `environment.variables.RUSTICL_ENABLE`.
      - It declares `myOpt.mesa-opencl.{enable=false, RUSTICL_ENABLE}` and would work if imported.
    - `2511/` is two files forming a Caddy compatibility shim for the 25.11 module API, documented in [`2511/HANDOVER.md`](2511/HANDOVER.md).

  - `mesa-opencl.nix`
    - It declares `enable = mkOption { type = types.bool; default = false; };`.
    - It declares `RUSTICL_ENABLE = mkOption { type = types.singleLineStr; };` with no default, so it must be set.
    - Its config is `mkIf cfg.enable` and sets `hardware.graphics.extraPackages = with pkgs; [ mesa.opencl ];` plus `environment.variables = { inherit (cfg) RUSTICL_ENABLE; };`.
    - It is unmaintained because `RUSTICL_ENABLE` is a **hardware-specific** escape hatch such as `radeonsi` or `llvmpipe` with no sensible default, and Mesa's OpenCL support changes shape between releases.
    - `mesa.opencl` is the post-24.05 attribute path, and older nixpkgs used `mesa.opencl` too but `hardware.opengl` instead of `hardware.graphics`, which matters if this repo is ever evaluated against `nixpkgs-2611`.
    - If you revive it, it belongs on the **laptop** path for GPU compute rather than on `vps-base`.
      - It is a sibling of `laptop-base/vi-ime.nix` and `cosmic.nix` in spirit as a hardware-specific opt-in, so consider moving it under `laptop-base/` instead of importing it from `nixos-base`.

  - Gotchas
    - **`RUSTICL_ENABLE` has no default**, so `myOpt.mesa-opencl.enable = true` alone fails, which is the main reason a `default = false` plus required-string pair lives in `unmaintained/` rather than `services/`.
    - Because the directory has no entry point, a `git grep myOpt.mesa-opencl` finds only this file, so do not assume it is active code when reviewing a rebuild log.
    - `2511/` inside this directory is **version-specific** rather than "unmaintained" in the same sense, since it was superseded when nixpkgs 25.11 landed, so do not merge the two concepts when cleaning up.

  - See also
    - [`2511/HANDOVER.md`](2511/HANDOVER.md) covers the Caddy shim.
    - [`../HANDOVER.md`](../HANDOVER.md) holds the live import list, from which this directory is absent.
    - [`../../HANDOVER.md`](../../HANDOVER.md) covers **G3**.
