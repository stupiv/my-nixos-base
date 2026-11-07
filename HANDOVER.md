# HANDOVER — repository root (`my-nixos-base`)

> **Snapshot:** 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · base commit `66ded62` ("2026-11-07T11:23:12 +07")
> **Authoring constraint:** `nix` was **not** installed in the sandbox that wrote these documents, so nothing here was
> build-tested. Everything below is derived from reading the source. Items that could not be verified are marked
> **⚠ verify**.

---

## 1. What this repo is (60-second orientation)

A personal, flake-parts-based **NixOS module library** — *not* a runnable system configuration. `flake.nix` exports
exactly two NixOS modules:

```nix
flake.nixosModules.laptop-base = ./laptop-base;
flake.nixosModules.vps-base    = ./vps-base;
```

A downstream host configuration (kept outside this repo) imports one of those two modules, supplies the mandatory
`myOpt.*` values, and adds per-machine hardware bits (`install/`). Every workload (Caddy, Cloudflared, Keycloak,
LiteLLM, n8n, Plausible, Frappe, Squid, …) is **opt-in** through option attributes; importing `nixos-base` alone starts
no application services.

Three ideas explain most of the code:

1. **`myOpt.*` is the option namespace.** Almost every module declares `options.myOpt.<thing>` and then walks
   `filterAttrs (_: cfg: cfg.enable) config.myOpt.<thing>` so that declaring an instance is what enables it.
2. **Unix sockets are the default transport.** Containers/services listen on `::1` or on a unix socket; Caddy,
   Cloudflared and `systemd-socket-proxyd` are the only things that face the network. This is what makes
   `sleep-on-idle`, `netns`, and `squid` composable.
3. **Laziness as a feature.** Services are `autoStart = false` and pulled up on demand by `sleep-on-idle` socket
   activation, which freezes the cgroup slice when idle.

---

## 2. Layout

| Path | Role | Handover |
| --- | --- | --- |
| `flake.nix`, `flake.lock` | Inputs, pinned nixpkgs revisions, the two module outputs | this file |
| `nixos-base/` | Shared server-side configuration: users, SSH, DNS, bootloader, and all services | [`nixos-base/HANDOVER.md`](nixos-base/HANDOVER.md) |
| `laptop-base/` | Desktop layer: hardware toggles, DE/Compositor, home-manager wiring | [`laptop-base/HANDOVER.md`](laptop-base/HANDOVER.md) |
| `vps-base/` | 6-line module: `../myPkgs` + `../nixos-base` | [`vps-base/HANDOVER.md`](vps-base/HANDOVER.md) |
| `install/` | disko partitioning + hardware config + deliberate `throw` reminders | [`install/HANDOVER.md`](install/HANDOVER.md) |
| `myLib/` | Helpers exposed as `pkgs.myLib` via overlay | [`myLib/HANDOVER.md`](myLib/HANDOVER.md) |
| `myPkgs/` | Pinned OCI image tags exposed as `pkgs.myPkgs` via overlay | [`myPkgs/HANDOVER.md`](myPkgs/HANDOVER.md) |

Composition:

```
                 ┌──────────────── flake.nixosModules.laptop-base ───────────────┐
                 │  laptop-base/default.nix                                     │
                 │    ├── ../nixos-base  ← shared server + terminal + services   │
                 │    ├── ./common       (nixpkgs overlays / substituters)       │
                 │    ├── ./cosmic.nix, ./plasma6.nix, ./de.nix  (DE choice)     │
                 │    ├── ./home-manager.nix → ./home-manager/*  (user profile)  │
                 │    └── ./appimage, bluetooth, firewall, ipv6, sound, tlp, …   │
                 └──────────────────────────────────────────────────────────────┘

                 ┌──────────────── flake.nixosModules.vps-base ─────────────────┐
                 │  vps-base/default.nix  →  ../myPkgs + ../nixos-base          │
                 └──────────────────────────────────────────────────────────────┘

                 install/  ← NOT imported by either module; the consumer host adds it
```

`nixos-base/default.nix` additionally re-imports `../myLib` and `../myPkgs`, so both scopes exist in either flavour.
(They are imported twice on the laptop path — harmless, module imports are idempotent.)

---

## 3. Inputs and pinning (`flake.nix`)

| Input | Pin | Notes |
| --- | --- | --- |
| `nixpkgs` | *follows* `nixpkgs-2605` | The default `pkgs` everywhere. |
| `nixpkgs-2605` | rev `7dcdd87` (nixos-26.05) | Comment links to `channels.nixos.org/nixos-26.05/git-revision`. |
| `nixpkgs-2611` | rev `3ec6363` (nixos-unstable) | Declared, but **not** wired into `pkgs`. See issue **G4**. |
| `home-manager` | `release-26.05`, follows `nixpkgs-2605` | Used by `laptop-base/home-manager.nix`. |
| `flake-parts` | `hercules-ci/flake-parts` | `mkFlake`, `systems = [x86_64-linux aarch64-linux]`. |
| `sops-nix` | `Mic92/sops-nix` | Imported by `nixos-base/sops.nix`. |
| `nix-index-database` | follows `nixpkgs` | Powers `comma`. |
| `disko` | `nix-community/disko` | Only used by `install/disko-config.nix`. |
| `nix-flatpak` | `gmodena/nix-flatpak?ref=latest` | home-manager flatpak module. |
| `zen-browser-flake` | `0xc000022070/zen-browser-flake` | home-manager only; `nixGL` enabled. |
| `nixos-hardware` | `NixOS/nixos-hardware` | **Not referenced by any module** — intended for `install/nixos-hardware.nix`. |
| `oisd` | `sjhgvr/oisd`, `flake = false` | `readFile`d by `nixos-base/dnscrypt/filter.nix`. |
| `hermes-agent` | `NousResearch/hermes-agent/v0.21.7` | Only used by an **unimported** file; comment explains "No inputs follows for cache to work". |

No CI, no formatter/treefmt config, no `README`, and `.gitignore` is empty. Formatting is hand-maintained and
consistently looks like `alejandra` output (2-space, one-arg-per-line) — **⚠ verify** which formatter is expected
before mass-reformatting.

---

## 4. Conventions you must follow

1. **`# ./default.nix` comment lines.** Nearly every `imports = [...]` list contains a commented-out self-import
   (`./default.nix`, `./defaut.nix`, `./unmaintained`). This is a deliberate marker, not dead weight: it keeps
   directory listing order and makes it obvious when a file was dropped from a list. Do not "clean these up".
2. **Per-instance submodules.** A service is an attribute set of *instances*:
   `options.myOpt.<svc> = mkOption { default = {}; type = types.attrsOf (types.submodule ({name, ...}: {...})); }`.
   The instance name is the key and is usually baked into unit/container/dir names (`"${name}-backend"`).
3. **`mkDefault` for anything a host may override**, `mkForce` only where a value must win (see `zramSwap`,
   `sleep-on-idle/set-cgroup-parent.nix`).
4. **sops secret naming:** `<instance-name>/<purpose>`, e.g. `test/litellm-envFile`, `test/frappe_envfile`.
   Consumers must have those keys in their sops file — the modules only declare `sops.secrets.<key>`.
5. **`enable` defaults are polarised:** top-level features (`myOpt.cosmic.enable`, `myOpt.zen-browser.enable`,
   `myOpt.easyeffects.enable`, `myOpt.mesa-opencl.enable`) default to **false**; per-service instance `enable`
   defaults to **true** so that *declaring* an instance turns it on.
6. **`types.anything` is used liberally** for pass-through config (`container`, `modules.services.*`,
   `authorizedKeys`, `hashedPassword`). There is almost no type safety on those paths — a typo only shows up at
   evaluation time.
7. **Names are load-bearing.** Container name, unit name, slice name, socket dir and state dir are all derived from
   the instance name by default. Renaming an instance renames its state directory.

---

## 5. Values a consumer **must** provide

`nixos-base` cannot evaluate standalone. Missing these is the usual first-hour failure:

| Option | Why it is mandatory | Where it is used |
| --- | --- | --- |
| `myOpt.admin.username` | no default, `types.anything` | `admin.nix`, `networkmanager.nix`, `dirs.nix` (default `homeDir`), `rclone-automount` |
| `myOpt.admin.hashedPassword` | no default | `users.users.<name>.hashedPassword` (generate with `mkpasswd`) |
| `myOpt.admin.authorizedKeys` | no default | also decides whether SSH is enabled at all |
| `myOpt.ipv6.public-address` | no default | `laptop-base/ipv6.nix` sets it to `null`; a VPS must set it (or `dnscrypt.ipv6.disable`) |
| `myOpt.dnscrypt.ipv6.disable` | no default | drives `block_ipv6` and Cloudflared `edgeIPVersion` |
| `system.stateVersion` | commented out in `install/stateVersion.nix` | must be set by the host |
| `myOpt.disk.{id,device}` | no default | `install/disko-config.nix` |

Everything else has defaults or is opt-in.

---

## 6. Deployment (inferred from `install/`, **⚠ verify**)

The `install/` layer plus its `throw` messages describe the intended flow:

1. Partition with **disko** (`install/disko-config.nix`: GPT → 1 MiB `EF02` BIOS-boot + 500 MiB ESP +
   btrfs root with `@root`/`@nix` subvolumes, `compress=zstd`).
2. Generate hardware config with **nixos-facter** — `install/hardware-configuration.nix` throws unless
   `./facter.json` exists, and the message names `nixos-anywhere --generate-hardware-config nixos-facter ./facter.json`.
3. Put the age key at `/var/lib/sops-nix/key.txt` — `install/reminders.nix` throws until you delete it, and
   `nixos-base/sops.nix` sets `sops.age.keyFile` to exactly that path.
4. Import the matching `nixos-hardware` module in `install/nixos-hardware.nix` (currently a bare `throw`).
5. `nixos-rebuild switch --flake .#<host>` (or `nixos-anywhere` for remote installs). No host configurations are
   defined in this flake, so the downstream config supplies `nixpkgs.hostPlatform`, `networking.hostName`, and the
   `myOpt` payload.

---

## 7. Known issues across the repo

Ordered roughly by how likely they are to bite. Each is repeated in the relevant sub-handover.

- **G1 — `netns` option shape vs. its consumers.** `nixos-base/services/netns.nix` exposes `nsPath` and
  `serviceUnit`, but `camofox.nix`, `fastcrw.nix` and `litellm.nix` each carry a local `resolveNetns` that reads
  `entry.path`, `entry.resolvConf`, `entry.unit`. Those attributes do not exist, so as soon as an instance *declares*
  `myOpt.netns.<name>`, evaluation fails instead of taking the `/run/netns/...` fallback. Either add
  `path`/`resolvConf`/`unit` aliases to `netns.nix`, or change the three call sites.
- **G2 — `install/` is orphaned.** Nothing imports it, and three of its six files are *intentional* `throw`s or
  placeholders (`reminders.nix`, `nixos-hardware.nix`, and the commented `stateVersion`). Do not "fix" the throws
  globally — they are the install-time checklist.
- **G3 — dormant directories.** `nixos-base/unmaintained/` (no `default.nix` at all),
  `laptop-base/unmaintained/`, `laptop-base/home-manager/unmaintained/`, and
  `nixos-base/services/compose/unmaintained/` (explicitly commented in `compose/default.nix`) are not in any import
  graph. They still get evaluated by tools that scan the tree, so they are not "free" to leave broken.
- **G4 — `pkgs.pkgs-2611` / `pkgs.pkgs-2605` are never defined.** `laptop-base/home-manager/activitywatch.nix`
  does `inherit (pkgs) pkgs-2611` and `easyeffects.nix` does `inherit (pkgs) pkgs-2605`, but the only overlay that
  could define them (`laptop-base/common/nixpkgs-overlays.nix`) is an empty stub with the line commented out.
  Because `activitywatch.nix` is imported unconditionally by `home-manager/default.nix`, the laptop profile will
  fail to evaluate unless the consumer defines those attributes. The commented overlay is the intended home for them.
- **G5 — `openssh.ports = [cfg.port]`** in `nixos-base/openssh.nix`: `port` defaults to `null`, so enabling SSH
  without setting a port yields `[ null ]`. Set `myOpt.openssh.port` whenever `enable` is true.
- **G6 — `nixos-base/services/compose/n8n-compose.nix` reads undeclared options** (`cfg.n8n.serviceName`,
  `cfg.proxy-compose.hostname`). It looks unfinished; treat it as WIP and do not enable it blind.
- **G7 — TLP settings contain an apparent typo** `USB_EXLUDE_PHONE` in `nixos-base/tlp.nix` (elsewhere in the file the
  key is spelled `USB_EXCLUDE_BTUSB`). **⚠ verify** against linrunner.de before trusting the comment's intent.
  Same file also pins charge thresholds 75/80 % for both batteries.
- **G8 — hard-coded locale/timezone** in `nixos-base/time.nix` (`Asia/Ho_Chi_Minh`, `LC_TIME = en_DK.UTF-8`).
  Intentional (24-hour clock in English), but a per-host override needs `mkForce`/`mkDefault` awareness.
- **G9 — `zramSwap.memoryPercent = 400` + `swapDevices = mkForce []`** — deliberate "no disk swap" policy; any host
  that wants a swapfile must override both.

---

## 8. Common tasks → where to go

| Task | Touch |
| --- | --- |
| Add a new always-on service | new `nixos-base/services/<name>.nix` + add to `nixos-base/services/default.nix` |
| Add a containerised app behind Caddy/Cloudflare | model it on `nixos-base/services/compose/plausible-compose.nix` (NixOS container) or `keycloak-compose.nix` |
| Change what the terminal looks like | `nixos-base/terminal/` (aliases + packages) |
| Change the desktop | `laptop-base/de.nix` (`myOpt.cosmic.enable`) or `myOpt.plasma6.enable` |
| Add a GUI app | `laptop-base/home-manager/packages.nix` |
| Bump a container image | `myPkgs/oci-img.nix` (image tags are centralised there; the per-service `image` options are `example`-only and must be passed explicitly) |
| Add a helper used by several modules | `myLib/<name>.nix` + add to `myLib/default.nix` |

---

## 9. Handover checklist for the next maintainer

1. `git log` is a single squashed commit — **there is no useful history here**; treat the tree as the source of truth.
2. Read `nixos-base/default.nix` and `laptop-base/default.nix` first; those two import lists *are* the table of contents.
3. Reproduce a build on a machine with Nix before changing anything: `nix flake check` will evaluate both modules but
   cannot catch the `myOpt.admin.*` gaps (they only appear when a host imports them).
4. Resolve **G1** and **G4** first — they are the two that turn a fresh checkout into an evaluation error.
5. The sandbox that produced these files had **no network access to `cache.nixos.org`**, so no substitution or build
   was attempted; all statements about runtime behaviour come from reading the units/services, not from running them.
