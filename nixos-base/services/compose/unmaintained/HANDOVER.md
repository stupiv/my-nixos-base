# HANDOVER — `nixos-base/services/compose/unmaintained/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

Retired or experimental compose-style modules. `../default.nix` has the line **commented out** (`# ./unmaintained`), so
nothing here is imported and nothing here is evaluated by either flake output. It is a reference shelf.

## Contents

| File | Lines | What it was | Why it is here |
| --- | --- | --- | --- |
| `chatwoot-compose.nix` | 277 | Chatwoot + `pgvector` (PostgreSQL) + Valkey, all unix-socket, `autoStart = false` | Superseded by the nspawn-based modules (`../plausible-compose.nix` is the closest live relative); it is an **OCI** (podman) design with in-container socket folders `/run/valkey`, `/run/chatwoot`, `/var/run/postgresql`, data dir `/data`, and env `POSTGRES_USER/POSTGRES_DB = "chatwoot"` |
| `compose-template.nix` | 51 | A **skeleton** for a new compose module | Shows the minimal contract: `modules.proxy-compose` pass-through, `serviceName = name` (readOnly), `networkNamespace`, `cgroup-parent`, and one `myOpt.proxy-compose` entry per instance |
| `wordpress/` | 3 files | WordPress + plugins + themes | See [`wordpress/HANDOVER.md`](wordpress/HANDOVER.md) |

## `compose-template.nix` — read this before writing a new module

```nix
options.myOpt.compose-template = attrsOf (submodule ({name, config, ...}: {
  options = {
    enable = { … default = true; };
    modules.proxy-compose = mkOption { type = types.anything; };
    serviceName = mkOption { type = types.singleLineStr; default = name; readOnly = true; };
    networkNamespace = …; cgroup-parent = …;
  };
}));
config.myOpt.proxy-compose =
  mapAttrs' (_: cfg: nameValuePair cfg.serviceName cfg.proxy-compose) enabled;
```

It is the smallest possible expression of the "one instance → one `proxy-compose` entry" pattern. Note it does **not**
declare any container at all — the actual workload is left to the caller. Also note that `serviceName = name` is
`readOnly`, which is the convention in the live modules too.

Caveat: it declares `networkNamespace` and `cgroup-parent` as plain options and then **never uses them** — in the live
code those moved into `modules.sleep-on-idle` / `netns` (`set-cgroup-parent`, `netns-id`). Do not copy those two blindly.

## Gotchas

- **Being here does not make a file safe to ignore.** A formatter, `deadnix`, or an LSP still parses these files; a
  syntax error here breaks tooling even though it cannot break a system closure.
- **These modules reference `myOpt` keys that still exist** (`proxy-compose`, `sleep-on-idle`), so `chatwoot-compose.nix`
  would probably *evaluate* if re-enabled — but it predates the `set-env-vars` / netns work, so its wiring would be
  incomplete (no `set-network-namespace`, no `set-cgroup-parent`). Re-enabling it is a port, not a line uncomment.
- **`chatwoot-compose.nix` uses `myPkgs`-style pinned tags conceptually** (`pgvector`, `valkey`, `chatwoot`) but hard-codes
  nothing — the tags now live in [`../../../../myPkgs/oci-img.nix`](../../../../myPkgs/oci-img.nix) as `chatwoot_v4`,
  `pgvector_v0_8_pg18`, `valkey_v8`. If you revive it, wire those in instead of inventing new strings.
- The parent file uses the comment-only style (`# ./unmaintained`), not a `disabledModules` mechanism, so there is no
  runtime switch to flip — re-enabling means editing `../default.nix`.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — the live modules and the shared patterns
- [`wordpress/HANDOVER.md`](wordpress/HANDOVER.md)
- [`../../../../HANDOVER.md`](../../../../HANDOVER.md) — G3
