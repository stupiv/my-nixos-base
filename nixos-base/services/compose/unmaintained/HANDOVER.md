- This is the handover for `nixos-base/services/compose/unmaintained/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds retired or experimental compose-style modules.
    - `../default.nix` has the line **commented out** as `# ./unmaintained`, so nothing here is imported and nothing here is evaluated by either flake output.
    - It is a reference shelf.

  - Contents
    - `chatwoot-compose.nix` is 277 lines implementing Chatwoot plus `pgvector` PostgreSQL plus Valkey, all unix-socket with `autoStart = false`.
      - It was superseded by the nspawn-based modules, of which `../plausible-compose.nix` is the closest live relative.
      - It is an **OCI** podman design with in-container socket folders `/run/valkey`, `/run/chatwoot` and `/var/run/postgresql`, data dir `/data`, and env `POSTGRES_USER/POSTGRES_DB = "chatwoot"`.
    - `compose-template.nix` is 51 lines and is a **skeleton** for a new compose module.
      - It shows the minimal contract of a `modules.proxy-compose` pass-through, `serviceName = name` as readOnly, `networkNamespace`, `cgroup-parent`, and one `myOpt.proxy-compose` entry per instance.
    - `wordpress/` is three files covering WordPress plus plugins and themes, documented in [`wordpress/HANDOVER.md`](wordpress/HANDOVER.md).

  - `compose-template.nix` — read this before writing a new module
    - It declares `options.myOpt.compose-template = attrsOf (submodule ({name, config, ...}: { options = { … }; }));`.
    - Inside it, `enable` defaults to `true`.
    - It declares `modules.proxy-compose = mkOption { type = types.anything; };`.
    - It declares `serviceName = mkOption { type = types.singleLineStr; default = name; readOnly = true; };`.
    - It declares `networkNamespace` and `cgroup-parent`.
    - Its config sets `config.myOpt.proxy-compose = mapAttrs' (_: cfg: nameValuePair cfg.serviceName cfg.proxy-compose) enabled;`.
    - It is the smallest possible expression of the "one instance → one `proxy-compose` entry" pattern.
    - Note that it does **not** declare any container at all, because the actual workload is left to the caller.
    - Note also that `serviceName = name` is `readOnly`, which is the convention in the live modules too.
    - The caveat is that it declares `networkNamespace` and `cgroup-parent` as plain options and then **never uses them**, since in the live code those moved into `modules.sleep-on-idle` and `netns` as `set-cgroup-parent` and `netns-id`, so do not copy those two blindly.

  - Gotchas
    - **Being here does not make a file safe to ignore**, because a formatter, `deadnix` or an LSP still parses these files and a syntax error here breaks tooling even though it cannot break a system closure.
    - **These modules reference `myOpt` keys that still exist** such as `proxy-compose` and `sleep-on-idle`, so `chatwoot-compose.nix` would probably *evaluate* if re-enabled.
      - It predates the `set-env-vars` and netns work, so its wiring would be incomplete with no `set-network-namespace` and no `set-cgroup-parent`, making re-enabling it a port rather than a line uncomment.
    - **`chatwoot-compose.nix` uses `myPkgs`-style pinned tags conceptually** for `pgvector`, `valkey` and `chatwoot` but hard-codes nothing.
      - The tags now live in [`../../../../myPkgs/oci-img.nix`](../../../../myPkgs/oci-img.nix) as `chatwoot_v4`, `pgvector_v0_8_pg18` and `valkey_v8`, so if you revive it, wire those in instead of inventing new strings.
    - The parent file uses the comment-only style `# ./unmaintained` rather than a `disabledModules` mechanism, so there is no runtime switch to flip and re-enabling means editing `../default.nix`.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers the live modules and the shared patterns.
    - [`wordpress/HANDOVER.md`](wordpress/HANDOVER.md) covers the WordPress stack.
    - [`../../../../HANDOVER.md`](../../../../HANDOVER.md) covers **G3**.
