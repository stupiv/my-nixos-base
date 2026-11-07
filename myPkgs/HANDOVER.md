- This is the handover for `myPkgs/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It is a second custom scope on `pkgs`, **`pkgs.myPkgs`**, built with the same `makeScope`/`overrideScope` trick as [`../myLib`](../myLib/HANDOVER.md).
    - Its only job today is to hold the **pinned OCI image tags** for the containerised services, so that image bumps are one-file, one-line changes instead of edits scattered across five compose modules.
    - `myPkgs/default.nix` reads `nixpkgs.overlays = [ (final: prev: { myPkgs = prev.lib.makeScope prev.newScope (self: { oci-img = prev.callPackages ./oci-img.nix {}; }); }) ];`.

  - Files
    - `default.nix` creates `pkgs.myPkgs` and wires `oci-img`, using plain `overlays` rather than `mkBefore` because it assumes `myLib`-style ordering is not needed.
    - `oci-img.nix` exposes `pkgs.myPkgs.oci-img.<name>` as an image reference **string** and is a `makeScope` of five pinned tags.

  - Pinned images (`oci-img.nix`)
    - `n8n_v2` is `docker.io/n8nio/n8n:2.28.7`, whose tag page comment points at hub.docker.com/r/n8nio/n8n/tags.
    - `mariadb_v11_8` is `docker.io/mariadb:11.8.8`, whose tag page comment points at hub.docker.com/_/mariadb/tags.
    - `chatwoot_v4` is `docker.io/chatwoot/chatwoot:v4.14.1-ce`, whose tag page comment points at hub.docker.com/r/chatwoot/chatwoot/tags.
    - `pgvector_v0_8_pg18` is `docker.io/pgvector/pgvector:0.8.2-pg18-trixie`, whose tag page comment points at hub.docker.com/r/pgvector/pgvector/tags.
    - `valkey_v8` is `docker.io/valkey/valkey:8.1.8-alpine`, whose tag page comment points at hub.docker.com/r/valkey/valkey/tags.
    - The naming convention is `<app>_v<major>[_<minor>][_<variant>]`.
    - The value is a **string** rather than a derivation, is fed to `virtualisation.oci-containers.containers.<name>.image` or to a `podman run` call, and is therefore never built or hashed by Nix.
      - The consequence is that **an image bump is not reproducible from the flake lock**, because the tag *is* the pin and a moved tag silently changes what runs.

  - Gotchas
    - The per-service modules do **not** default to these attributes.
      - For example `nixos-base/services/compose/n8n-compose.nix` declares `n8n.image = mkOption { example = "docker.io/n8nio/n8n:2.14.2"; }`, which is an `example` and not a `default`, so the host config must pass `pkgs.myPkgs.oci-img.n8n_v2` explicitly.
      - The same applies to `frappe-v16-compose` (`mariadb.image`, `valkey.image`), mostly because those modules are also used with locally built images.
    - There is a **version skew** worth knowing about, since `n8n_v2` is `2.28.7` while the `example` in `n8n-compose.nix` says `2.14.2`, making the example stale documentation rather than a pin.
    - `myPkgs` is imported by `nixos-base/default.nix` and again by `vps-base/default.nix`, which is idempotent but means the overlay ordering is defined twice.
    - `oci-img.nix` takes `{ lib, newScope }` and makes a *nested* scope, so the access path is `pkgs.myPkgs.oci-img.<attr>` at three levels rather than `pkgs.myPkgs.<attr>`.
    - No `myPkgs` flake output exists, so like `myLib` it is only reachable through `nixos-base` or `vps-base`.

  - How to extend
    - Add the image tag to `oci-img.nix` with a comment linking to its tag page.
    - If you need an actual derivation such as a wrapper or a patched package, add it to the `makeScope` body in `myPkgs/default.nix` as `foo = prev.callPackage ./foo.nix {};` and keep `oci-img` for strings only.
    - Prefer consuming tags as `pkgs.myPkgs.oci-img.<name>` in host configs rather than hard-coding strings, so the bump stays a one-line diff.

  - See also
    - [`../nixos-base/services/compose/HANDOVER.md`](../nixos-base/services/compose/HANDOVER.md) covers the consumers.
    - [`../myLib/HANDOVER.md`](../myLib/HANDOVER.md) covers the identical scope-building pattern.
