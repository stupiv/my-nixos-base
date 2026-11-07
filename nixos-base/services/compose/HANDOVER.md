# HANDOVER — `nixos-base/services/compose/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

"Compose-like" multi-component applications — the things you would normally write a `docker-compose.yml` for, expressed
as NixOS modules. Two different runtime styles live here side by side:

| Style | Mechanism | Used by |
| --- | --- | --- |
| **NixOS containers** (`containers.<name>`) | systemd-nspawn, shares the host store, `ephemeral = true` | `plausible-compose.nix`, `keycloak-compose.nix` |
| **OCI containers** (`virtualisation.oci-containers`) | podman, pinned image tags | `frappe-v16-compose/`, `n8n-compose.nix` |

```nix
# compose/default.nix
imports = [
  ./frappe-v16-compose
  # ./unmaintained        ← deliberately off
  ./hermes-agent-compose.nix
  ./keycloak-compose.nix
  ./n8n-compose.nix
  ./plausible-compose.nix
];
```

`./unmaintained` (chatwoot, wordpress, `compose-template.nix`) is **commented out** — see
[`unmaintained/HANDOVER.md`](unmaintained/HANDOVER.md).

## The shape every file follows

1. Declare `options.myOpt.<app>-compose = attrsOf (submodule ({name, ...}: { options = { enable; modules.*; … }; }))`.
2. `enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.<app>-compose;`
3. Wire into the primitives from `../`:
   - `myOpt.proxy-compose.<id>` → Caddy vhost / Cloudflare tunnel / sleep-on-idle instance,
   - `myOpt.sleep-on-idle.<id>` → health-check path + `endpoints.default`,
   - `myOpt.netns.<id>` → the container(s) plus the proxy get their own network namespace,
   - `myOpt.squid.<id>` → egress allowlist (frappe only, so far).
4. `containers.<name>.config` (or `virtualisation.oci-containers.containers`) holds the actual unit(s).
5. `sops.secrets."<name>/<purpose>"` for every env file / keybase file — never a value, only a path.
6. `autoStart = false` + `set-cgroup-parent` so the whole stack is pulled up on first request and frozen afterwards.

The `modules` sub-attribute (`modules.proxy-compose`, `modules.sleep-on-idle`, `modules.squid`,
`modules.services.*`) is **pass-through configuration from the host**: the module merges its own defaults *before* it
(`mkMerge [ cfg.modules.<x> { …defaults… } ]`), so the host can override, and in a few places
`mkMerge [ …defaults… cfg.modules.<x> ]` — check the order in the file you touch, it is not consistent.

## File by file

### `plausible-compose.nix` (NixOS container, well-formed)

Plausible analytics: one nspawn container holding **plausible + PostgreSQL + ClickHouse**. Options:
`plausible.{package,stateDir}`, `postgresql.{package,stateDir}`, `clickhouse.{package,stateDir}`,
`secretKeybaseFile-key` (default `<name>/secretKeybaseFile`), `shared-run-secrets` (read-only dir bind-mounted into the
container, derived via `builtins.dirOf` from the sops secret path).

Notable: it bind-mounts the **host** paths of `DynamicUser` services — including
`/var/lib/private/plausible` — and asserts `systemd.services.plausible.serviceConfig.DynamicUser`, because bind-mounting
at `/var/lib/plausible` would not work under `DynamicUser`. The `tmpfiles` rules create all three state dirs with
unspecified perms (`- - - - -`), i.e. the services' own `StateDirectory` logic wins. This file is the best template in
the repo.

### `keycloak-compose.nix` (NixOS container)

Keycloak + PostgreSQL inside one container, published through a **unix socket** rather than a port. This file is thin: it
delegates to `myOpt.keycloak.<name>` and `myOpt.postgresql.<name>` and only wires the pieces together —
`myOpt.proxy-compose` takes `endpoints.default.origin.ip-socket = myOpt.keycloak.<name>.unix-socket`, so the Caddy /
tunnel / sleep-on-idle chain lives in `../proxy-compose.nix`. The proxyd itself is created by
[`../../keycloak.nix`](../HANDOVER.md), which imports `../../../systemd-socket-proxyd.nix` *inside the container's config*
and reads `localMode`/`hostname` from this file's `proxy-compose` entry. `modules.keycloak`, `modules.postgresql` and
`modules.proxy-compose` are pass-through.

### `n8n-compose.nix` (podman) — **WIP, do not enable blind**

Pinned `n8n.image`, two state dirs (`~/.n8n`, `~/.n8n-files`) with `tmpfiles 700 1000 1000`, `ports = ["host:port:port"]`
and a sleep-on-idle registration using `/healthz/readiness`.

**Known breakage (G6):** it reads `cfg.n8n.serviceName` (never declared) and `cfg.proxy-compose.hostname` (the option is
`modules.proxy-compose`), and it looks up `config.myOpt.proxy-compose.${cfg.n8n.containerName}.cloudflared` — a key that
`proxy-compose.nix` does not create (it keys by instance *name*, not container name). Evaluating an enabled n8n instance
should fail. Treat as unfinished; `myPkgs/oci-img.nix` already carries `n8n_v2 = 2.28.7` for when it is finished.

### `hermes-agent-compose.nix` (NixOS container) — **skeleton**

Declares a large option surface (`hermes-agent.{user,group,uid,gid,stateDir,port,unix-socket,settings,extra-users}`,
`modules.{netns,sleep-on-idle,fastcrw,litellm,camofox,searxng}`, `telemetry`) and then a config that is mostly
**empty `mkMerge (mapAttrsToList (_: cfg: { }) enabled)` blocks** — the plumbing for `myOpt.netns`, `myOpt.camofox`,
`myOpt.litellm`, `sops.secrets` is stubbed.

What *is* implemented: users/groups, the `settings` **`apply`** (a `recursiveUpdate` that forces firecrawl backends,
`browser.cloud_provider = "camofox"`, `model.base_url = ${myOpt.litellm.<name>.url}/v1`, telemetry toggles,
`moa.presets.default.enabled = false`), a two-endpoint sleep-on-idle instance (`default` → hermes socket,
`litellm` → LiteLLM socket), and the container itself.

**Additional breakage:** it references `outerCfg.myOpt.searxng.<name>`, but **no `myOpt.searxng` option exists anywhere
in the repo** (the enabling code is commented out at line ~159). `searxng` is also referenced in the container's
`after`/`wants` list. Anything that forces `optionalAttrs cfg.modules.searxng.enable …` while `enabled` fails, because
`outerCfg.myOpt.searxng.${name}` is evaluated eagerly in the `let`. It also uses `netnsCfg.path` / `.resolvConf`, i.e.
**G1** again.

### `frappe-v16-compose/` (podman, the largest thing in the repo)

See [`frappe-v16-compose/HANDOVER.md`](frappe-v16-compose/HANDOVER.md).

## Gotchas

- **Two runtimes, one repo.** A NixOS container shares `/nix/store` with the host and starts via `container@<name>.service`;
  a podman container is a separate image and starts via `container-<name>-<service>.service`. The primitives that enumerate
  units know this (`set-cgroup-parent.nix` maps `"container@${nixos-con}"` vs
  `virtualisation.oci-containers.containers.<c>.serviceName`; `netns.nix` does the same) — if you add a new consumer of
  those lists, copy the mapping exactly.
- **`config.containers.<name>.config` reads are self-referential.** `plausible-compose.nix` reads
  `config.containers.${name}.config` *outside* the container to copy `services.postgresql.dataDir` and
  `services.clickhouse…StateDirectory` into bind mounts. That works because NixOS modules are fixed-point, but it means
  the inner attr must be *declared* by the inner config, otherwise you get an infinite recursion or a missing attribute.
- **`ephemeral = true`** is used everywhere: the container's root filesystem is reset on every restart, so *all*
  persistence must go through `bindMounts`. Forgetting a bind mount silently loses data on restart, not on first start.
- **`nixpkgs.pkgs = pkgs`** must be set inside each container config (`plausible` does), otherwise nspawn containers
  re-evaluate a whole nixpkgs and the build explodes.
- **`sops.secrets` path vs. `builtins.dirOf`:** mounting a single secret file into a container is awkward, so the modules
  mount the *parent directory* (read-only). That directory also contains the age-key-derived plaintext of other
  secrets — check `shared-run-secrets` before reusing it for a container you do not fully trust.
- Nothing here sets `virtualisation.oci-containers.backend = "podman"` globally; `frappe-compose.nix` and
  `camofox.nix` set it locally.

## How to add an app

Copy `plausible-compose.nix` if the app is a NixOS package (fastest, shares the store), or `frappe-compose.nix` if it
needs an upstream image. Either way: declare `myOpt.<app>-compose`, wire `proxy-compose` + `sleep-on-idle`, add state
dirs via `tmpfiles`, pass secrets through sops, and set `autoStart = false` with `set-cgroup-parent`.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — primitives (`netns`, `sleep-on-idle`, `squid`, `proxy-compose`)
- [`../sleep-on-idle/HANDOVER.md`](../sleep-on-idle/HANDOVER.md)
- [`../../../HANDOVER.md`](../../../HANDOVER.md) — §7 (G1, G6)
- [`../../../myPkgs/HANDOVER.md`](../../../myPkgs/HANDOVER.md) — pinned image tags
