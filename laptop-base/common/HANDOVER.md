# HANDOVER — `laptop-base/common/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

One file, imported from **two different worlds**:

- `laptop-base/default.nix` → `./common` (as a **NixOS** module),
- `laptop-base/home-manager/default.nix` → `../common` (as a **home-manager** module).

So whatever lives here must be valid in *both* module systems — which is why its only content is `nix.settings` and
`nixpkgs.overlays`. Both of those exist in NixOS and (via `nix`-awareness in home-manager) are at least tolerated;
anything OS-specific here would break the home-manager import.

## Files

| File | Contents |
| --- | --- |
| `default.nix` | `imports = [ ./nixpkgs-overlays.nix ];` |
| `nixpkgs-overlays.nix` | adds the `hermes-agent.cachix.org` substituter + its public key, and an **empty** `nixpkgs.overlays` entry holding a commented-out experiment |

## `nixpkgs-overlays.nix`, line by line

```nix
nix.settings = {
  substituters = [ "https://hermes-agent.cachix.org" ];
  trusted-public-keys = [ "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU=" ];
};
nixpkgs.overlays = [
  (final: prev: {
    # lib = prev.lib.extend (lfinal: lprev: {
    #   inherit (final.pkgs-2611.lib) customisation;
    # });
  })
];
```

Two things are worth flagging:

1. **This is the only place in the repo that adds a substituter beyond `nixos-base/nix.nix`** (which sets
   `cache.nixos.org` + `nix-community.cachix.org`). Because NixOS merges lists, the effective substituter set on the
   laptop is the union of both — the VPS gets only the `nixos-base` pair. The cachix cache matches the
   `hermes-agent` flake input (`NousResearch/hermes-agent`), whose comment in `flake.nix` says *"No inputs follows for
   cache to work"*: following inputs would change the derivation hashes and miss the cache.
2. **The overlay is an empty function.** It is a placeholder — the commented body is the abandoned attempt to extend
   `lib` with something from a second nixpkgs (`final.pkgs-2611.lib`). That attribute does not exist anywhere in the repo
   (**G4**), which is exactly why this block is commented out and why
   [`../home-manager/activitywatch.nix`](../home-manager/activitywatch.nix) and `easyeffects.nix` cannot evaluate as
   written.

## Why `pkgs-2611` / `pkgs-2605` matter here

`flake.nix` pins two nixpkgs revisions (`nixpkgs-2605` as the default, `nixpkgs-2611` for unstable packages), but
**nothing maps them onto `pkgs.pkgs-2605` / `pkgs.pkgs-2611`**. The natural home for that mapping is this file:

```nix
# not present — what it probably should look like
nixpkgs.overlays = [ (final: prev: {
  pkgs-2605 = import inputs.nixpkgs-2605 { inherit (prev.stdenv.hostPlatform) system; };
  pkgs-2611 = import inputs.nixpkgs-2611 { inherit (prev.stdenv.hostPlatform) system; };
}) ];
```

(Needs `inputs` threaded in — the file currently only takes `{ }` implicitly, i.e. no arguments at all, so adding this
requires changing both consumers.)

## Gotchas

- **Dual-import duplication.** `common` is imported by both `laptop-base` and `laptop-base/home-manager`, so the
  substituter list is declared twice on the laptop path. Module deduplication makes it harmless, but if you add
  something *stateful* (a `systemd` unit, a `home.file`) here, it will be defined from both contexts and may conflict.
- **A home-manager module cannot set `nix.settings.substituters` meaningfully** (it is a system setting); the import is
  tolerated, not useful, on that side. Keep this file to things that are harmless in both.
- **`trusted-public-keys` is security-relevant.** A substituter key is permission to inject store paths. `hermes-agent`
  is a third-party cache; if the project is dropped, delete both lines — leaving an orphan key quietly expands the trust
  root.
- The `nix.settings` here is *merged* with `nixos-base/nix.nix` (which sets `experimental-features`, `trusted-users`).
  Do not add `substituters` here expecting to replace; use `mkForce` if you really mean to.

## How to extend

Keep it to declarations that are (a) idempotent and (b) meaningful in both NixOS and home-manager: overlays, `nix.settings`,
`nixpkgs.config`. For anything OS-only, create a sibling file and import it **only** from `laptop-base/default.nix`.

## See also

- [`../../HANDOVER.md`](../../HANDOVER.md) — §3 inputs, §7 **G4**
- [`../HANDOVER.md`](../HANDOVER.md) — how `common` is imported from both sides
- [`../home-manager/HANDOVER.md`](../home-manager/HANDOVER.md) — the unconditional `activitywatch` import that trips G4
