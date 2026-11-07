- This is the handover for `nixos-base/unmaintained/2511/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It is a **backport/polyfill of the Caddy module options that nixpkgs 25.11 introduced**, written so the repo could run against an older nixpkgs or so a host could pin the new behaviour early.
    - It is now dormant, because `2511/default.nix` exists and imports `./caddy.nix` but its parent `nixos-base/unmaintained/` has no `default.nix`, so nothing pulls it in.
    - The directory name is the nixpkgs release it targets (`25.11`) rather than an upstream project.

  - `caddy.nix` — what it declares
    - It declares `openFirewall = mkOption { type = types.bool; default = false; };` under `options.services.caddy`.
    - It declares `httpPort = mkOption { default = 80;  type = with types; nullOr port; };`.
    - It declares `httpsPort = mkOption { default = 443; type = with types; nullOr port; };`.
    - Its config sets `networking.firewall` under `mkIf cfg.openFirewall` with `allowedTCPPorts = filter (port: port != null) [ cfg.httpPort cfg.httpsPort ];`.
    - The same block sets `allowedUDPPorts = optional (cfg.httpsPort != null) cfg.httpsPort;`.
    - In other words it provides exactly `services.caddy.openFirewall`, `httpPort` and `httpsPort` plus the firewall wiring.

  - Why it exists and why it is dormant
    - On **nixpkgs 26.05**, the pinned default `nixpkgs-2605` in `flake.nix`, those options are part of `services.caddy` upstream, so this file would be a **duplicate declaration** and cause an evaluation error.
    - On an older pin they are missing, and importing this file makes the rest of the repo work, since `nixos-base/services/proxy-compose.nix` sets `services.caddy.openFirewall` and `laptop-base/firewall.nix` sets `services.caddy.openFirewall = false`.
    - It is kept as a marker, so if the repo is ever pinned back or forward across the 25.11 boundary this is the shim.

  - Gotchas
    - **The firewall semantics are subtle and copied faithfully**, because TCP gets both ports null-filtered while UDP gets **only** `httpsPort` given that HTTP/3 is QUIC over UDP/443, so do not "simplify" it to `allowedUDPPorts = allowedTCPPorts`.
    - **Do not import this together with a nixpkgs that already defines the options.**
      - The failure is a hard "The option `services.caddy.openFirewall' has conflicting definitions" style error, and it will only appear when a host imports `unmaintained/2511`, which is never in CI of this repo.
    - The directory is named after a nixpkgs release, so it will look stale forever, which is expected.
      - If you delete it, delete `2511/default.nix` too, because a dangling import list is worse than nothing.
    - `types` is used unqualified as `with types; nullOr port`, which is fine inside `with lib;` at the top of the file but matters if you copy the block into a file with a different `with` prelude.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) explains why this parent directory is inert.
    - [`../../HANDOVER.md`](../../HANDOVER.md) covers `caddy.nix` with the NSS PATH fix and the real import list.
    - [`../../../laptop-base/HANDOVER.md`](../../../laptop-base/HANDOVER.md) covers `firewall.nix`, which sets `services.caddy.openFirewall`.
