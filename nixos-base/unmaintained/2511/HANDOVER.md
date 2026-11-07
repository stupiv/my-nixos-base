# HANDOVER — `nixos-base/unmaintained/2511/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

A **backport/polyfill of the Caddy module options that nixpkgs 25.11 introduced** — written so the repo could run against
an older nixpkgs, or so that a host could pin the new behaviour early. It is now dormant: `2511/default.nix` exists and
imports `./caddy.nix`, but its parent `nixos-base/unmaintained/` has no `default.nix`, so nothing pulls it in.

The directory name is the nixpkgs release it targets (`25.11`), not an upstream project.

## `caddy.nix` — what it declares

```nix
options.services.caddy = {
  openFirewall = mkOption { type = types.bool; default = false; };
  httpPort     = mkOption { default = 80;  type = with types; nullOr port; };
  httpsPort    = mkOption { default = 443; type = with types; nullOr port; };
};
config.networking.firewall = mkIf cfg.openFirewall {
  allowedTCPPorts = filter (port: port != null) [ cfg.httpPort cfg.httpsPort ];
  allowedUDPPorts = optional (cfg.httpsPort != null) cfg.httpsPort;
};
```

i.e. exactly `services.caddy.openFirewall` / `httpPort` / `httpsPort` and the firewall wiring.

## Why it exists / why it is dormant

- On **nixpkgs 26.05** (the pinned default, `nixpkgs-2605` in `flake.nix`) those options are part of
  `services.caddy` upstream, so this file would be a **duplicate declaration** → evaluation error.
- On an older pin they are missing, and importing this file makes the rest of the repo work
  (`nixos-base/services/proxy-compose.nix` sets `services.caddy.openFirewall`, and `laptop-base/firewall.nix` sets
  `services.caddy.openFirewall = false`).
- It is kept as a marker: if the repo is ever pinned back or forward across the 25.11 boundary, this is the shim.

## Gotchas

- **The firewall semantics are subtle and copied faithfully:** TCP gets both ports (null-filtered), UDP gets **only**
  `httpsPort` (because HTTP/3 is QUIC over UDP/443). Do not "simplify" it to `allowedUDPPorts = allowedTCPPorts`.
- **Do not import this together with a nixpkgs that already defines the options.** The failure is a hard
  "The option `services.caddy.openFirewall' has conflicting definitions" style error, and it will only appear when a
  host imports `unmaintained/2511` — i.e. never in CI of this repo.
- The directory is named after a nixpkgs release, so it will look stale forever. That is expected; if you delete it,
  delete `2511/default.nix` too (a dangling import list is worse than nothing).
- `types` is used unqualified (`with types; nullOr port`) — fine inside `with lib;` at the top of the file, but keep
  that in mind if you copy the block into a file with a different `with` prelude.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — why this parent directory is inert
- [`../../HANDOVER.md`](../../HANDOVER.md) — `caddy.nix` (the NSS PATH fix) and the real import list
- [`../../../laptop-base/HANDOVER.md`](../../../laptop-base/HANDOVER.md) — `firewall.nix` sets `services.caddy.openFirewall`
