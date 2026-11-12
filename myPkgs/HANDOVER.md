1. `myPkgs/` exposes centralized OCI image references through `pkgs.myPkgs.oci-img`.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. `default.nix` creates the package scope through an overlay.
        1. It uses `makeScope` and `prev.callPackages ./oci-img.nix {}`.
        2. `oci-img.nix` creates a nested scope of image-reference strings rather than derivations.
        3. Import `myPkgs`, `nixos-base`, or `vps-base` because no dedicated flake output exists.
        4. Repeated imports through `nixos-base` and `vps-base` are deduplicated.
    3. The snapshot pins five image tags.
        1. `n8n_v2` refers to `docker.io/n8nio/n8n:2.28.7`.
        2. `mariadb_v11_8` refers to `docker.io/mariadb:11.8.8`.
        3. `chatwoot_v4` refers to `docker.io/chatwoot/chatwoot:v4.14.1-ce`.
        4. `pgvector_v0_8_pg18` refers to `docker.io/pgvector/pgvector:0.8.2-pg18-trixie`.
        5. `valkey_v8` refers to `docker.io/valkey/valkey:8.1.8-alpine`.
        6. Attribute names follow `<app>_v<major>[_<minor>][_<variant>]`.
    4. Consumers must select these tags explicitly.
        1. Service image options generally provide examples rather than defaults.
        2. Pass `pkgs.myPkgs.oci-img.<name>` from host configuration.
        3. The n8n module's `2.14.2` example is stale relative to the centralized `2.28.7` tag.
        4. Frappe also requires explicit MariaDB and Valkey image selections.
        5. Tag strings are neither built nor content-hashed by Nix, so mutable tags remain outside flake-lock reproducibility.
    5. Extend the scope according to the artifact type.
        1. Add image strings to `oci-img.nix` with comments linking to upstream tag pages.
        2. Add actual derivations to `myPkgs/default.nix` with `prev.callPackage` instead.
        3. Keep host consumers on centralized attributes to make image bumps local changes.
    6. Read the related handovers for scope and consumer details.
        1. The [compose handover](../nixos-base/services/compose/HANDOVER.md) describes image consumers.
        2. The [library handover](../myLib/HANDOVER.md) describes the sibling scope-building pattern.
