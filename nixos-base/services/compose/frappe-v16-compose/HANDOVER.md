# HANDOVER — `nixos-base/services/compose/frappe-v16-compose/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix`, no podman
> in the authoring sandbox).

## What this directory is for

A full **Frappe/ERPNext v16 bench** (frontend, backend, websocket, two queue workers, scheduler, MariaDB, two Valkey
instances, configurator, create-site, migrate) as podman containers on one host — the single most complex piece of the
repo. The interesting part is not the container list; it is the two build-time/run-time tricks:

1. **The bench lives in the Nix store.** `frappe-bench-store.sh` `podman run`s the official `frappe/build` image to
   `bench init` into a temp dir, then `nix store add-path`s the result and points a **gcroot** symlink at it. That
   symlink is both GC protection *and* the stable mount source for every container.
2. **Everything inner-container talks over unix sockets.** MariaDB runs with `--skip-networking`, both Valkey instances
   use `--port 0 --unixsocket`, gunicorn binds `unix:/run/frappe/gunicorn.sock`. Only the frontend nginx listens on
   `127.0.0.1:8080`, and that is inside a network namespace.

```
┌─ host ────────────────────────────────────────────────────────────────────────┐
│ <name>-build.service  (oneshot)   frappe-bench-store.sh → nix store + gcroot   │
│      requiredBy: container@<name>-configurator.service                        │
│                                                                               │
│ netns <netns-id>  ──────────────────────────────────────────────────────────  │
│   mariadb (999:999, skip-networking, /run/mysqld/mysqld.sock)                 │
│   valkey-cache (--port 0, /run/valkey-cache/valkey.sock, --save '')           │
│   valkey-queue (--port 0, /run/valkey-queue/valkey.sock, persistent dir)      │
│   configurator → create-site → migrate → backend/queue-*/scheduler/websocket  │
│   frontend (nginx) 127.0.0.1:8080                                             │
│   squid@<name> (egress allowlist) + sleep-on-idle proxies                     │
│                                                                               │
│ proxy-compose.<id> → caddy vhost / cloudflared tunnel → sleep-on-idle socket  │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Files

| File | Role |
| --- | --- |
| `default.nix` | imports `frappe-compose.nix` + `options.nix` |
| `options.nix` | **all** the options for `myOpt.frappe-v16-compose.<name>` (236 lines, no `config`) |
| `frappe-compose.nix` | the implementation: containers, units, tmpfiles, netns/squid/proxy wiring |
| `frappe-bench-store.sh` | host-side: build the bench with podman, capture into the Nix store, gcroot it, record a spec hash |
| `bench-init.sh` | **in-container**: `bench init --apps_path=/opt/frappe/apps.json …`, strip `.git`, drop `logs` |
| `bench-readonly.sh` | host-side guard used instead of the store script when `frappe.readOnlyMode = true` |
| `configurator.sh` | **in-container**: writes `sites/common_site_config.json` (db socket, both valkey sockets, socketio port, maintenance flags, `host_name`) |
| `create-site.sh` | **in-container**: waits for sockets + config, `bench new-site`, marks `sites/<site>/.site-created` |
| `migrate.sh` | **in-container**: waits for `.site-created`, installs missing apps from `$APPS`, `bench migrate` |
| `unmaintained/frappe-compose.backup.nix` | a 576-line earlier version — see its [handover](unmaintained/HANDOVER.md) |

`options.nix` and `frappe-compose.nix` are deliberately split because the option tree is big enough that mixing it with
`config` becomes unreadable. Keep that split.

## Option surface (abridged)

```nix
myOpt.frappe-v16-compose.<name> = {
  enable = true;
  proxy-compose-id = name;      # key into myOpt.proxy-compose
  sleep-on-idle-id = <derived from proxy-compose>;   # readOnly
  netns-id = name;
  sopsFile = name;              # one sops file holding both env files
  frappe.readOnlyMode = false;  # ← the switch that makes redeploys safe
  frappe.stateDir / sitesPath / logsPath / benchDir / siteName
  frappe.apps.<app> = { enable; url = "https://github.com/frappe/<app>"; branch; };
  frappe.base.tag  = "v16.x.y"  # → image docker.io/frappe/base:<tag>
  frappe.build.tag = …          # defaults to frappe.apps.erpnext.branch
  mariadb.{image,stateDir,envfile-key}
  valkey.{image,stateDir}, valkey.cache.{containerName,socket-folder}, valkey.queue.{…}
  modules.{proxy-compose,squid}
};
```

Secrets expected in the sops file: `<name>/frappe_envfile` (`INIT_ADMIN_PASSWORD`, `DB_PASSWORD`) and
`<name>/mariadb_envfile` (`MARIADB_ROOT_PASSWORD`).

## Invariants and assertions

- `!(frappe.apps ? "erpnext") || frappe.build.tag == frappe.apps.erpnext.branch` — the ERPNext app branch and the
  builder image tag are the **same thing** (see `frappe_docker/docker-bake.hcl`).
- `!(frappe.apps ? "helpdesk") || frappe.apps ? "telephony"` — helpdesk requires telephony.
- The build unit's `requiredBy`/`before` the configurator: **nothing else may start before the bench exists.**
- `dependsOn` chains the OCI containers: mariadb+valkeys → configurator → create-site → migrate → (backend, queues,
  scheduler, websocket) → frontend.
- `readOnlyMode = true` flips four things at once: the build unit runs `bench-readonly.sh` (which *fails* if no bench
  exists), create-site runs with `READONLY=1` and refuses to create a new site, migrate short-circuits, and the
  configurator sets `maintenance_mode=1` + `allow_reads_during_maintenance=1`.

## The `readOnlyMode` story (worth internalising)

This is the deploy-safety mechanism. First deployment must be `readOnlyMode = false`: it builds the bench into the store,
creates the site, installs apps, migrates. Afterwards you flip it to `true`, and redeploying **cannot** touch the bench or
the site — the build unit only checks that a bench exists and warns that changes are ignored. `migrate.sh` logs
`readOnlyMode is enabled; skipping app sync and migrate.` So: to actually upgrade, you set `false`, switch, and set it
back. `bench-readonly.sh` exits 1 (rather than 0) when there is no bench, precisely so a fresh host does not silently
come up broken.

## Storage layout

`tmpfiles` creates, with exact ownership (Frappe containers run as uid 1000, MariaDB/Valkey as 999, group 0):

```
<frappe.stateDir><sitesPath>   0770 1000:0    ← sites/, assets/
<frappe.stateDir><logsPath>    0770 1000:0
<backend.socket-folder>        0750 1000:0    /run/<name>/backend
<mariadb.stateDir>             0700 999:999
<mariadb.socket-folder>        0750 999:0
<valkey.stateDir>              0750 999:0
<valkey.queue.stateDir>        0700 999:0  + Z (recursive chown) 
<valkey.cache.socket-folder>   0750 999:0
<valkey.queue.socket-folder>   0750 999:0
```

Getting these wrong is the #1 cause of "container exits immediately": MariaDB refuses to start if `datadir` is not
`0700` and owned by 999, and gunicorn cannot bind if the socket folder is not writable by 1000.

## Gotchas

- **The bench is in the Nix store and is mounted `:O`** (overlay). Writes stay in the container's overlay except for the
  explicitly mounted `sites`/`logs` dirs. Do not expect `bench` commands run by hand outside the container to persist.
- **`frappe-bench-store.sh` writes to the store as the invoking user**, so the unit must run as root (or with
  `nix.settings.trusted-users` covering it). `nix store add-path` + `nix-store --add-root` are the two privileged steps.
- **The spec hash is `<apps.json><branch><builder-tag>` sha256, first 12 chars**, stored next to the gcroot
  (`<GCROOT>-hash`). `FORCE=1` bypasses the skip. Consequence: changing *anything else* (env, resource limits) does not
  rebuild the bench; changing the apps list does. `apps.json` is a `writeText` in the store, so its path changes with
  content — the hash follows.
- **`bench-init.sh` `rm -rf`s `.git` and `logs`** before capture, so the store path is small and reproducible-ish; it also
  seeds `sites/common_site_config.json` with `{}` so the configurator has something to merge into.
- **`configurator.sh` writes `sites/apps.txt`** from `ls -1 apps`; without it `bench` complains about a missing apps list.
- **The `assets` bind mount is a sub-path of `sites`** (`<benchDir>/sites/assets`) mounted read-only and `noexec`; the
  overlay `:O` mount of the whole bench is the writable one. The ordering of these two mounts matters.
- **Socket paths are duplicated three times** (host path → in-container path → env var `*_SOCKET`). Changing one without
  the others yields a container that hangs in `create-site.sh`'s `until [ -S … ]` loop forever.
- **`mariadb-socket` is passed as `--socket=`** with `--skip-networking`; there is no TCP path to the database at all.
  `MARIADB_SERVICE = "localhost"` in the configurator only satisfies Frappe's config schema.
- **The frontend binds `127.0.0.1:8080`**, and `proxy-compose`'s health check for frappe is
  `endpoints.default.origin = { host = "127.0.0.1"; port = 8080; }` with `/api/method/ping`. Inside a netns that
  `127.0.0.1` is the namespace's loopback, not the host's.
- **G1 applies here too**: `frappe-compose.nix` reads `myOpt.netns.<id>` only for its own declaration
  (`set-network-namespace`), so it is fine — but `myOpt.sleep-on-idle.<id>.endpoints.default.proxy.name` is read
  cross-module, meaning the sleep-on-idle instance must exist with a `default` endpoint.
- The whole stack is `autoStart = false`; `hostname` comes from `cfg.modules.proxy-compose.hostname` and is baked into
  the configurator's `HOST_NAME` (`https://…`). If you change the tunnel hostname you must re-run the configurator
  container, not just the tunnel.

## Upgrading Frappe (checklist)

1. Bump `frappe.base.tag` **and** `frappe.apps.<app>.branch` (they must agree; the assertion enforces it).
2. Bump `mariadb.image` / `valkey.image` from [`../../../../myPkgs/oci-img.nix`](../../../../myPkgs/oci-img.nix).
3. `readOnlyMode = false`, switch, watch `<name>-build` → configurator → create-site → migrate.
4. `readOnlyMode = true` again, switch.
5. If the site is half-created, `create-site.sh` refuses to touch it and prints the two recovery options
   (`touch sites/<site>/.site-created`, or `bench drop-site … --force --no-backup`). Read that message before improvising.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — compose patterns, nspawn vs podman, `ephemeral`
- [`../sleep-on-idle/HANDOVER.md`](../../sleep-on-idle/HANDOVER.md) — the freeze/thaw front door
- [`../../HANDOVER.md`](../../HANDOVER.md) — `squid.nix` (egress allowlist) and `netns.nix`
- [`unmaintained/HANDOVER.md`](unmaintained/HANDOVER.md) — the previous generation of this module
