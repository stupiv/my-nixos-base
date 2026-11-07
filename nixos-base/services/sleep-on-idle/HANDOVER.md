# HANDOVER — `nixos-base/services/sleep-on-idle/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

**On-demand services that cost nothing when unused.** A unix-socket proxy sits in front of an app; when the app is
idle, its whole cgroup slice is `systemctl freeze`d; the next connection to the socket thaws it, runs a health check,
and hands over. This is the mechanism that lets ~15 containers coexist on one small VPS.

Split across five files because the five concerns are genuinely separate:

| File | Concern |
| --- | --- |
| `options.nix` | declares `myOpt.sleep-on-idle.<name>` |
| `socket.nix` | one `.socket` per endpoint, `wantedBy = sockets.target` |
| `proxy.nix` | one `systemd-socket-proxyd` service per endpoint + the health-check script |
| `slice.nix` | one `<sliceName>.slice` per instance |
| `freeze.nix` | the `sleep-on-idle-freeze@<slice>` unit that freezes/thaws |
| `set-cgroup-parent.nix` | pushes the *real* services into that slice |
| `default.nix` | import list (`# ./default.nix` marker) |

## Data model

```nix
myOpt.sleep-on-idle.<name> = {
  enable            = true;
  sliceName         = name;                       # → <sliceName>.slice
  endpoints.<ep>    = {
    origin = { host, port };                      # where the real app listens  (unbracketed)
    proxy  = { host, port, ip-socket };           # default ip-socket: /run/sleep-on-idle/<slice>/<ep>.sock
    name   = "sleep-on-idle-proxy@<slice>-<ep>";  # read-only unit name
  };
  exit-idle-time    = 300;                        # seconds passed to --exit-idle-time
  TimeoutStartSec   = 30;
  health-check      = { host, port, ip-socket, path, sleep = "1" };
  set-cgroup-parent = { systemd-services = [ … ]; oci-containers = [ … ]; nixos-containers = [ … ]; };
  freezeName/freezeUnit  (read-only);
};
```

Both `origin`/`proxy`/`health-check` come from `pkgs.myLib.mkEndpointOpt` — see
[`../../../myLib/HANDOVER.md`](../../../myLib/HANDOVER.md) for the bracket rules. Note the split:
`origin` and `proxy` are unbracketed/bracketed respectively **for systemd**, while `health-check` is **bracketed**
because it is used to build a `curl` URL.

## The lifecycle, end to end

```
client → /run/sleep-on-idle/<slice>/<ep>.sock
           │  (socket unit: TriggerLimitBurst = 0, NoDelay = true)
           ▼
   sleep-on-idle-proxy@<slice>-<ep>.service
     requires/after: the .socket + sleep-on-idle-freeze@<slice>.service
     ExecStartPre : health-check loop  ── thaw happens because the freeze unit is Started
     ExecStart    : systemd-socket-proxyd --exit-idle-time=<exit-idle-time> <origin.ip-socket>
           │
           ▼
   <slice>.slice  ← contains the app's units (set-cgroup-parent)
        freeze unit: ExecStart = -systemctl thaw %i.slice
                     ExecStop  = -systemctl freeze %i.slice
```

Key details:

- **The freeze unit is started, not stopped, to wake.** `freeze.nix` sets `RemainAfterExit = true`,
  `StopWhenUnneeded = true`, `ExecStart = thaw`, `ExecStop = freeze`. Because the proxy `requires` it, stopping the proxy
  (which happens when `systemd-socket-proxyd` exits after `--exit-idle-time`) stops the freeze unit, which runs
  `ExecStop` = freeze. Elegant, and easy to misread.
- **Both `ExecStart`/`ExecStop` are prefixed with `-`**, so "already frozen" or "not frozen" is not an error.
- **`set-cgroup-parent.nix` forces `wantedBy = ["<freezeUnit>"]`** on the app units and `StopWhenUnneeded = false`, so
  the app is only wanted while the freeze unit is active, and is not torn down by unrelated unneeded-propagation.
  It also injects `--cgroup-parent=<slice>` into oci-containers, because podman otherwise escapes the slice.
- **Health check is a build-time script** (`writeShellScriptBin "<slice>-health-check"`) with a `until … do sleep …`
  loop. Three branches: unix socket + `phpfpm` → `cgi-fcgi -bind -connect`; unix socket otherwise → `curl --unix-socket`;
  TCP → plain `curl`. `assert (health-check.ip-socket != null)` guards a missing default.
- **`TriggerLimitBurst = 0`** disables systemd's start-rate limiter on the socket — otherwise a burst of connections
  would trip the limiter and *permanently* refuse the socket.
- Default `exit-idle-time` is 300 s, so a "cold" service costs one round trip (~health check + thaw) per 5 minutes of
  idle time, not per request.

## Consumers

Declared by (grep for `myOpt.sleep-on-idle`):

- `services/proxy-compose.nix` — creates an instance per published app, id = `cfg.sleep-on-idle-id`;
- `services/squid.nix` — puts the squid + its two proxyd units in a slice;
- `services/litellm.nix` — optional, via `cfg.sleep-on-idle`;
- `services/compose/*-compose.nix` — n8n, plausible, frappe, keycloak, chatwoot.
- `services/compose/frappe-v16-compose/frappe-compose.nix` also references
  `myOpt.sleep-on-idle.<id>.endpoints.default.proxy.name` inside the netns's `set-network-namespace.systemd-services`,
  i.e. it needs the instance to exist with a `default` endpoint. That is a **cross-module read of a declared option** —
  change the sleep-on-idle option shape and frappe breaks.

## Gotchas

- **`endpoints.default` is assumed by several modules** even though the option allows any key. If you only define
  `endpoints.api`, `proxy-compose.nix` (which reads `endpoints.default.proxy.ip-socket` in
  `default-caddy-origin-unix-socket`) fails at evaluation.
- **`health-check.ip-socket` defaults to `endpoints.default.origin.ip-socket`**, so a missing `origin` makes the
  `assert` fire with a very unhelpful "assertion failed" message.
- **The health-check runs *inside the host namespace*.** For a netns-attached app the origin `::1:port` is not the
  host's `::1`. The composed modules therefore attach the proxy to the namespace (via `myOpt.netns…`) or point
  `origin.ip-socket` at the proxied unix socket.
- **Freezing is a cgroup operation**, so anything the app holds open (sockets, DB connections) is frozen mid-flight.
  Only idempotent, restartable services belong in a slice; do not add a database to `set-cgroup-parent` blindly.
- `freeze.nix` uses `${config.systemd.package}/bin/systemctl` **without** `--machine` or `sudo`, and the unit runs as
  root with no sandboxing — this is the one place where the repo trades hardening for "it must work".
- Slices are created empty (`nameValuePair cfg.sliceName {}`); systemd creates the cgroup on first member.

## How to extend

Add an endpoint to an existing instance (just declare `endpoints.<ep>`), or create a whole instance and then reference
its `freezeUnit`/`sliceUnit` from a service module's `set-cgroup-parent`. Start from
`services/compose/plausible-compose.nix` for a realistic example. If your app has no HTTP health endpoint, point
`health-check` at whatever is cheap and idempotent (the frappe module uses `/api/method/ping`).

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — primitives 2/4/5 and the composition diagram
- [`../../../myLib/HANDOVER.md`](../../../myLib/HANDOVER.md) — `mkEndpointOpt` and bracket rules
- [`../compose/HANDOVER.md`](../compose/HANDOVER.md) — the biggest consumers
