1. `compose/unmaintained/` stores retired and experimental application compositions.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../../HANDOVER.md).
    2. The parent import list comments out `# ./unmaintained`.
        1. No runtime toggle activates this directory.
        2. Re-enabling modules requires editing imports and porting their wiring.
        3. Dormant files still need valid syntax for formatters, analyzers, and editors.
    3. `chatwoot-compose.nix` preserves an OCI-based Chatwoot stack.
        1. Components include Chatwoot, pgvector PostgreSQL, and Valkey with unix sockets and `autoStart = false`.
        2. Container socket paths include `/run/valkey`, `/run/chatwoot`, and `/var/run/postgresql`.
        3. Persistent data uses `/data` and the PostgreSQL user and database are named `chatwoot`.
        4. The stack predates current namespace, cgroup, and environment-injection primitives.
        5. Revival requires current `set-network-namespace` and `set-cgroup-parent` integration rather than merely uncommenting an import.
        6. Select `chatwoot_v4`, `pgvector_v0_8_pg18`, and `valkey_v8` from the [central image definitions](../../../../myPkgs/oci-img.nix).
    4. `compose-template.nix` is a minimal but outdated skeleton.
        1. It declares enabled-by-default `myOpt.compose-template` instances.
        2. `serviceName` defaults to the instance name and is read-only.
        3. It declares a `modules.proxy-compose` pass-through without creating a workload container.
        4. Its mapping reads `cfg.proxy-compose` despite declaring `modules.proxy-compose`.
        5. Its plain `networkNamespace` and `cgroup-parent` options are unused and should not be copied into new modules.
        6. Prefer active compose examples for current namespace and cgroup wiring.
    5. [`wordpress/`](wordpress/HANDOVER.md) preserves native WordPress composition and fetcher overlays.
        1. That directory has no entry point and requires explicit imports even if its parent is revived.
    6. Read the related handovers before porting dormant modules.
        1. The [live compose handover](../HANDOVER.md) describes current application patterns.
        2. The [WordPress handover](wordpress/HANDOVER.md) covers its fetchers and runtime.
        3. The [root handover](../../../../HANDOVER.md) records dormant-directory issue **G3**.
