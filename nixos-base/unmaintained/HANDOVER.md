1. `nixos-base/unmaintained/` holds parked modules outside both flake outputs.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. This directory has no `default.nix` and no active directory import.
        1. Adding an entry point does not activate anything unless a consumer also imports it.
        2. Keep dormant modules syntactically valid for tree-scanning tooling.
    3. `mesa-opencl.nix` preserves optional Rusticl and OpenCL configuration.
        1. `myOpt.mesa-opencl.enable` defaults to `false`.
        2. `myOpt.mesa-opencl.RUSTICL_ENABLE` is a required single-line string without a default.
        3. Enabled configuration adds `mesa.opencl` to `hardware.graphics.extraPackages` and exports `RUSTICL_ENABLE`.
        4. Hardware-specific values include `radeonsi` and `llvmpipe`.
        5. Enabling the module without a driver value fails evaluation.
        6. Revival requires checking Mesa and graphics-option compatibility against the chosen nixpkgs pin.
        7. Prefer the laptop layer for hardware-specific GPU compute support.
    4. [`2511/`](2511/HANDOVER.md) preserves a version-specific Caddy compatibility shim.
        1. Its dormant status reflects upstream replacement rather than unfinished hardware configuration.
    5. Read the related handovers before changing imports.
        1. The [Caddy-shim handover](2511/HANDOVER.md) describes its version boundary.
        2. The [shared-system handover](../HANDOVER.md) lists active imports.
        3. The [root handover](../../HANDOVER.md) records dormant-directory issue **G3**.
