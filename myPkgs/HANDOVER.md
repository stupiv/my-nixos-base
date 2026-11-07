# HANDOVER — `myPkgs/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

A second custom scope on `pkgs` — **`pkgs.myPkgs`** — built with the same `makeScope`/`overrideScope` trick as
[`../myLib`](../myLib/HANDOVER.md). Its only job today is to hold the **pinned OCI image tags** for the containerised
services, so that image bumps are one-file, one-line changes instead of edits scattered across five compose modules.

```nix
# myPkgs/default.nix
nixpkgs.overlays = [ (final: prev: {
  myPkgs = prev.lib.makeScope prev.newScope (self: {
    oci-img = prev.callPackages ./oci-img.nix {};
  });
}) ];
```

## Files

| File | Exposes | Notes |
| --- | --- | --- |
| `default.nix` | creates `pkgs.myPkgs`, wires `oci-img` | plain `overlays`, not `mkBefore` — it assumes `myLib`-style ordering is not needed |
| `oci-img.nix` | `pkgs.myPkgs.oci-img.<name>` → image reference **string** | a `makeScope` of five pinned tags |

## Pinned images (`oci-img.nix`)

| Attribute | Reference | Upstream tag page (comment in file) |
| --- | --- | --- |
| `n8n_v2` | `docker.io/n8nio/n8n:2.28.7` | hub.docker.com/r/n8nio/n8n/tags |
| `mariadb_v11_8` | `docker.io/mariadb:11.8.8` | hub.docker.com/_/mariadb/tags |
| `chatwoot_v4` | `docker.io/chatwoot/chatwoot:v4.14.1-ce` | hub.docker.com/r/chatwoot/chatwoot/tags |
| `pgvector_v0_8_pg18` | `docker.io/pgvector/pgvector:0.8.2-pg18-trixie` | hub.docker.com/r/pgvector/pgvector/tags |
| `valkey_v8` | `docker.io/valkey/valkey:8.1.8-alpine` | hub.docker.com/r/valkey/valkey/tags |

Naming convention: `<app>_v<major>[_<minor>][_<variant>]`. The value is a **string**, not a derivation — it is fed to
`virtualisation.oci-containers.containers.<name>.image` or to a `podman run` call, so it is never built or hashed by
Nix. Consequence: **an image bump is not reproducible from the flake lock** — the tag *is* the pin, and a moved tag
silently changes what runs.

## Gotchas

- The per-service modules do **not** default to these attributes. E.g. `nixos-base/services/compose/n8n-compose.nix`
  declares `n8n.image = mkOption { example = "docker.io/n8nio/n8n:2.14.2"; }` — an `example`, not a `default`, so the
  host config must pass `pkgs.myPkgs.oci-img.n8n_v2` explicitly. The same applies to `frappe-v16-compose`
  (`mariadb.image`, `valkey.image`), mostly because those modules are also used with locally built images.
- There is a **version skew** worth knowing about: `n8n_v2` is `2.28.7` while the `example` in `n8n-compose.nix` says
  `2.14.2`. The example is stale documentation, not a pin.
- `myPkgs` is imported by `nixos-base/default.nix` and again by `vps-base/default.nix`. Idempotent, but it means the
  overlay ordering is defined twice.
- `oci-img.nix` takes `{ lib, newScope }` and makes a *nested* scope, so the access path is
  `pkgs.myPkgs.oci-img.<attr>` (three levels), not `pkgs.myPkgs.<attr>`.
- No `myPkgs` flake output exists — like `myLib`, it is only reachable through `nixos-base`/`vps-base`.

## How to extend

1. Add the image tag to `oci-img.nix` with a comment linking to its tag page.
2. If you need an actual derivation (a wrapper, a patched package), add it to `myPkgs/default.nix`'s `makeScope`
   body (`foo = prev.callPackage ./foo.nix {};`) and keep `oci-img` for strings only.
3. Prefer consuming tags as `pkgs.myPkgs.oci-img.<name>` in host configs rather than hard-coding strings, so the
   bump stays a one-line diff.

## See also

- [`../nixos-base/services/compose/HANDOVER.md`](../nixos-base/services/compose/HANDOVER.md) — the consumers
- [`../myLib/HANDOVER.md`](../myLib/HANDOVER.md) — the identical scope-building pattern
