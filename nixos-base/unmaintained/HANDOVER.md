# HANDOVER — `nixos-base/unmaintained/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

Parked modules. **There is no `default.nix` here and nothing imports the directory**, so it is fully outside the
evaluation graph of both flake outputs. Unlike `services/compose/unmaintained/` (which is excluded by a commented
import), this one is excluded simply by not having an entry point — so if you ever add a `default.nix`, everything
inside becomes live at once. Keep that in mind.

## Contents

| File | Lines | What it is | Status |
| --- | --- | --- | --- |
| `mesa-opencl.nix` | 25 | Opt-in Rusticl/OpenCL: `hardware.graphics.extraPackages = [ mesa.opencl ]` + `environment.variables.RUSTICL_ENABLE` | Options declared (`myOpt.mesa-opencl.{enable=false, RUSTICL_ENABLE}`); would work if imported |
| `2511/` | 2 files | A Caddy compatibility shim for the 25.11 module API | See [`2511/HANDOVER.md`](2511/HANDOVER.md) |

## `mesa-opencl.nix`

```nix
options.myOpt.mesa-opencl = {
  enable = mkOption { type = types.bool; default = false; };
  RUSTICL_ENABLE = mkOption { type = types.singleLineStr; };   # ← no default, must be set
};
config = mkIf cfg.enable {
  hardware.graphics.extraPackages = with pkgs; [ mesa.opencl ];
  environment.variables = { inherit (cfg) RUSTICL_ENABLE; };
};
```

Why unmaintained: `RUSTICL_ENABLE` is a **hardware-specific** escape hatch (e.g. `radeonsi`, `llvmpipe`) with no
sensible default, and Mesa's OpenCL support changes shape between releases. `mesa.opencl` is the post-24.05 attribute
path; older nixpkgs used `mesa.opencl` too but `hardware.opengl` instead of `hardware.graphics`, which matters if this
repo is ever evaluated against `nixpkgs-2611`.

If you revive it: it belongs on the **laptop** path (GPU compute), not on `vps-base`, and it is a sibling of
`laptop-base/vi-ime.nix`/`cosmic.nix` in spirit — i.e. a hardware-specific opt-in, so consider moving it under
`laptop-base/` instead of importing it from `nixos-base`.

## Gotchas

- **`RUSTICL_ENABLE` has no default**, so `myOpt.mesa-opencl.enable = true` alone fails. That is the main reason a
  `default = false` + required-string pair lives in `unmaintained/` rather than `services/`.
- Because the directory has no entry point, a `git grep myOpt.mesa-opencl` finds only this file — do not assume it is
  active code when reviewing a rebuild log.
- `2511/` inside this directory is **version-specific**, not "unmaintained" in the same sense; it was superseded when
  nixpkgs 25.11 landed. Do not merge the two concepts when cleaning up.

## See also

- [`2511/HANDOVER.md`](2511/HANDOVER.md)
- [`../HANDOVER.md`](../HANDOVER.md) — the live import list (this directory is absent from it)
- [`../../HANDOVER.md`](../../HANDOVER.md) — G3
