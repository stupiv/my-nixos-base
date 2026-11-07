# HANDOVER — `nixos-base/services/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix` in the
> authoring sandbox).

## What this directory is for

Every long-running workload in the repo. All of it is **opt-in**: importing this directory declares options only; each
service starts doing work the moment a host writes `myOpt.<service>.<name> = { … };`.

```nix
# nixos-base/services/default.nix
imports = [
  ./compose  ./sleep-on-idle
  ./camofox.nix ./cloudflared.nix ./fastcrw.nix ./keycloak.nix ./litellm.nix
  ./mariadb.nix ./netns.nix ./postgresql.nix ./proxy-compose.nix ./rclone-automount.nix
  ./squid.nix ./systemd-socket-proxyd.nix ./valkey.nix
];
```

## The five primitives (learn these first)

Everything else is a composition of these. They are worth reading in this order:

### 1. `netns.nix` — network namespaces

`myOpt.netns.<name>` creates a `netns-<name>.service` (`ip netns add <ns>`, `lo up`, hashed short name by default, e.g.
7 hex chars of `sha256 name`) and lets you *attach* things to it:

| Field | Effect |
| --- | --- |
| `set-network-namespace.systemd-services` | `NetworkNamespacePath` + `InaccessiblePaths = /run/nscd /run/resolvconf` + `bindsTo`/`after` the netns unit |
| `set-network-namespace.oci-containers` | `networks = [ "ns:/run/netns/<ns>" ]` |
| `set-network-namespace.nixos-containers` | `networkNamespace = /run/netns/<ns>` |

The service itself is heavily sandboxed (`CAP_NET_ADMIN`+`CAP_SYS_ADMIN` only, `IPAddressDeny = "any"`,
`MemoryDenyWriteExecute`, …). Design intent: an app that should not reach the network at all still gets a namespace with
a loopback, and only explicitly proxied sockets leave it.

> **G1 — this is the biggest latent bug in the repo.** `camofox.nix`, `fastcrw.nix` and `litellm.nix` each contain a
> local copy of `resolveNetns` that reads `entry.path`, `entry.resolvConf`, `entry.unit`. `netns.nix` declares none of
> those; it has `nsPath` and `serviceUnit` and no `resolvConf` at all. The `or null` fallback saves you **only** when no
> `myOpt.netns.<name>` is declared. Declare one and those modules fail with *"attribute 'path' missing"*.

### 2. `systemd-socket-proxyd.nix` — TCP ↔ unix socket bridge

`myOpt.systemd-socket-proxyd.<name>` with `origin` (where to dial) and `proxy` (where to listen):

- both sides use `mkEndpointOpt` from [`../../myLib`](../../myLib/HANDOVER.md) — `origin` **unbracketed**, `proxy`
  **bracketed** (`listenStreams` needs `[::1]:8080`);
- emits a `systemd-socket-proxyd@<name>.socket` drop-in (`wantedBy = sockets.target`) plus a service drop-in whose
  `ExecStart` is the proxyd binary with the origin address, `requires`/`after` the origin unit;
- the templated `systemd-socket-proxyd@` socket/service pair is declared once as an empty base.

This is how a container that only speaks unix sockets gets exposed to Caddy/Cloudflared without opening a port.

### 3. `sleep-on-idle/` — socket activation + cgroup freeze

See [`sleep-on-idle/HANDOVER.md`](sleep-on-idle/HANDOVER.md). In one sentence: a `sleep-on-idle-proxy@…` unit fronts a
unix socket, runs a health check, then `systemd-socket-proxyd --exit-idle-time=…`, and the whole cgroup slice is frozen
when the proxy exits.

### 4. `squid.nix` — egress proxy with an FQDN allowlist

`squid@<name>` in a `netns`, listening on `[origin.host]:origin.port` (loopback inside the namespace), reachable from
outside via `systemd-socket-proxyd`. `HTTP(S)_PROXY`/`NO_PROXY` are then injected into the configured
`set-env-vars.{systemd-services,oci-containers,nixos-containers}`.

- `egress-restriction.enable = true` (default) writes Squid ACLs that only allow `CONNECT` to port 443 for
  `egress-restriction.fqdns` — everything else is denied;
- `validateConfig = true` (default) runs `squid -k parse` **at build time** via `runCommand`, so a bad config fails the
  build rather than the service;
- `DynamicUser`, `CacheDirectory`, `LogsDirectory`, `ProtectSystem = strict`, `CapabilityBoundingSet = ""`,
  `MemoryDenyWriteExecute`, `NoExecPaths`, `UMask = 0077` — this is the most hardened unit in the repo;
- the `squid@` template has `ConditionPathExists = /etc/squid/%i.conf`, so instances exist as
  `/etc/squid/<name>.conf` (written with `environment.etc`, i.e. no per-instance unit duplication).

### 5. `proxy-compose.nix` — the "publish this app" convenience layer

`myOpt.proxy-compose.<name>` ties together: a `sleep-on-idle` instance (default id = instance name), Caddy
(`virtualHosts.<hostname>` or `http://<localMode.ip-socket>`), and optionally Cloudflared
(`ingress.<hostname> = "unix:<socket>"`).

- **Invariant:** `localMode.enable` and `cloudflared.enable` are mutually exclusive — enforced by an `assertion`.
- `cloudflared.enable` is *read-only*, derived from `modules.cloudflared != {}`.
- `default-caddy-origin-unix-socket` is derived from the sleep-on-idle default endpoint and prefixed with `unix/`
  when it is a path, because that is Caddy's unix-socket syntax.
- `caddy.openFirewall` is only set when neither local mode nor cloudflared is on (Cloudflared tunnels need no port).

## Service-by-service

| File | `myOpt` key | Shape | What it really does |
| --- | --- | --- | --- |
| `camofox.nix` | `camofox` | `oci-containers` (podman) | Headless Firefox ("camofox") per instance: `--read-only`, `--cap-drop=ALL`, `--shm-size=2g` (default 64 MB breaks Firefox), sops env file, optional netns + cgroup-parent, telemetry flag → `CAMOFOX_CRASH_REPORT_ENABLED` |
| `fastcrw.nix` | `fastcrw` | native systemd unit | Stateless web-scraper/search API (`crw-server`), `DynamicUser`, huge `SystemCallFilter`, `EnvironmentFile` from sops, `autoStart = false` by default (pulled up on demand) |
| `litellm.nix` | `litellm` | **NixOS container** (`containers.<name>`) | LLM gateway. Creates state + socket dirs via `tmpfiles`, binds them in, exposes `myOpt.systemd-socket-proxyd.litellm` inside the container, telemetry env vars flipped by `cfg.telemetry`, and optionally registers itself with `sleep-on-idle` (health path `/health/liveliness`) |
| `keycloak.nix` | `keycloak` | NixOS container | Keycloak in an isolated container with a unix socket (`/run/<shared-run-dir>/keycloak.sock`) via `systemd-socket-proxyd`; forces `http-host = ::1`, `http-port = 25546`, `proxy-headers = xforwarded`; database type/host/createLocally are passed through from the module config |
| `valkey.nix` | `valkey` | NixOS container | Enables `services.redis` with a valkey package inside a container; `modules.services.redis` and `container` are pass-through attr sets (the `container` must carry `name`) |
| `mariadb.nix` | `mariadb` | NixOS container | Same pattern for `services.mysql`, with `dataDir = <container.stateDir>/mariadb` |
| `postgresql.nix` | `postgresql` | NixOS container | Same pattern for `services.postgresql`, plus a `tmpfiles` rule creating the state dir `0700 postgres postgres` |
| `cloudflared.nix` | `cloudflared` | tunnels | One tunnel per `<name>`; credentials from sops (`sops.tunnel-credentials.{key,sopsFile}`), `ingress` from `tunnelCfg`, `default = "http_status:404"`, `edgeIPVersion` chosen from `myOpt.dnscrypt.ipv6.disable`, `requires`/`after` `dnscrypt-proxy.service`, restart policy with stepped backoff |
| `rclone-automount.nix` | `rclone.automount` | `fileSystems` + `x-systemd.automount` | One rclone mount per remote, defaults `vfs-cache-mode=full`, `vfs-cache-max-age=90d`, `vfs-cache-min-free-space=20G`, `uid`/`gid` from the admin user, `allow_other`, `nofail`, `_netdev` |
| `squid.nix` | `squid` | templated systemd + netns | see primitive 4 |
| `systemd-socket-proxyd.nix` | `systemd-socket-proxyd` | templated systemd | see primitive 2 |
| `netns.nix` | `netns` | systemd + containers | see primitive 1 |

Composed directories: [`compose/`](compose/HANDOVER.md) (containerised apps) and
[`sleep-on-idle/`](sleep-on-idle/HANDOVER.md).

## Shared idioms you will see copy-pasted in every file

`camofox.nix`, `fastcrw.nix` and `litellm.nix` each duplicate ~40 lines of helpers:

```nix
outerCfg = config;
enabled   = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.<svc>;
secretKey = name: "${name}/<svc>-envFile";         # sops naming convention
mkHttpUrl = host: port: "http://[<v6>]:<port>";    # local bracket handling, does not use myLib
toSliceUnit = p: if p == null then null else if hasSuffix ".slice" p then p else "${p}.slice";
resolveNetns = nsName: …                            # see G1
```

When you touch one, consider whether the identical block in the other two should change too — the duplication is the
main source of drift here (`mkHttpUrl` re-implements `myLib.bracketIpv6` rather than using it).

**sops naming contract:** every module declares `sops.secrets."<instance>/<purpose>"` and never creates the file. Missing
keys in the host's sops file surface as "secret does not exist" at activation, not at build time.

## Gotchas specific to this directory

- **`autoStart = false` is the norm** for containers (`camofox`, `litellm`, `n8n`, `frappe`, `chatwoot`). A container that
  "is not running" is usually correct — it should be pulled up by `sleep-on-idle`/`systemd-socket-proxyd`. Check the
  socket unit before debugging the container.
- **`virtualisation.oci-containers.backend = "podman"` is set per-module** (`camofox.nix`, `frappe-compose.nix`), *not*
  globally. A new oci-containers module must set it, or the default `docker` backend will be requested and fail.
- **Instances are keyed by name and that name leaks into paths**: state dirs, `/run/netns/<hash>`, container names,
  slice names, sops keys. Renaming an instance orphans its state.
- **`types.anything` everywhere** means typos in `container` / `modules.services.*` pass evaluation of the *option* and
  only explode when the referenced attribute is forced — often deep in a `mkMerge`.
- **`litellm.nix` uses `ReadWritePaths = [stateDir]` with `ProtectSystem = "strict"`**, so a state dir outside the
  default `tmpfiles` rule needs its own `ReadWritePaths`, otherwise the container's service cannot write.
- **`rclone-automount` default `options.cache-dir` point at `.cache/rclone/myOpt.rclone.automount`** — the *option path*
  was pasted into the directory name. **⚠ verify:** it is literally interpolated as a literal string, so the cache dir is
  named after the option, not after the remote. Almost certainly unintended.
- **G6 — `n8n-compose.nix` (in `compose/`) is WIP**: it references `cfg.n8n.serviceName` and `cfg.proxy-compose.hostname`,
  neither of which is declared.

## How to add a service

1. Copy the smallest similar module (`fastcrw.nix` for native units, `litellm.nix` for a container with a socket).
2. Declare `options.myOpt.<svc>` as `attrsOf (submodule ({name, ...}: { options = { enable = mkOption { default = true; }; … }; }))`.
3. Build the config with `mkIf (enabled != {})` so the whole file disappears when nothing is declared.
4. Decide the transport: unix socket (preferred) → `systemd-socket-proxyd`; published → `proxy-compose`.
5. Add sops keys as `<instance>/<purpose>`; never default a secret path.
6. `./default.nix` + a line in the import list; leave the `# ./default.nix` marker convention intact.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — system-level modules the services depend on (`sops`, `nix`, `no-coredump`)
- [`../../HANDOVER.md`](../../HANDOVER.md) — §7 global issues (G1, G6), §8 task table
- [`../../myLib/HANDOVER.md`](../../myLib/HANDOVER.md) — `mkEndpointOpt` / bracket helpers
