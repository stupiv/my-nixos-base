# HANDOVER — `myLib/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

Six tiny overlay modules that build a **custom Nix library scope** reachable as `pkgs.myLib`. Nothing here is a NixOS
option; it exists so that service modules can write `inherit (pkgs) myLib;` and use helpers that know about IPv6
bracket rules and endpoint options.

```nix
# myLib/base.nix — creates the (initially empty) scope
nixpkgs.overlays = lib.mkBefore [
  (final: prev: { myLib = prev.lib.makeScope prev.newScope (self: {}); })
];
```

Every other file then does `prev.myLib.overrideScope (ml-final: ml-prev: { … })`, i.e. **each file adds one attribute
to the same scope**. Order therefore does not matter and files can be added without touching existing ones — but the
scope must exist first, which is why `base.nix` uses `mkBefore`.

`nixos-base/default.nix` and `vps-base/default.nix` both import `../myLib`. There is no `myLib` flake output, so a host
that wants these helpers must import the directory (or `nixos-base`).

## Files

| File | Adds to `pkgs.myLib` | Notes |
| --- | --- | --- |
| `base.nix` | *(creates the scope)* | `mkBefore`, so `myLib` exists for the rest |
| `splitLastColon.nix` | `splitLastColon : string → { host, port }` | `builtins.match "^(.*):([^:]*)$"` — greedy, so it splits on the **last** colon; `port = null` when there is no colon |
| `bracketIpv6.nix` | `bracketIpv6 : string → string` | leaves the string alone if it has no port, is already bracketed, or the host has no `:`; otherwise `[host]:port` |
| `unbracketIpv6.nix` | `unbracketIpv6 : string → string` | inverse: strips `[...]` before a port |
| `mkEndpointOpt.nix` | `mkEndpointOpt { cfg, ipv6-brackets, default-ip-socket ? null, ... }` | **returns an option set**: `port`, `host`, `ip-socket` |
| `replaceModules.nix` | `replaceModules : nixpkgs-x → [modulePath] → [module]` | emits `disabledModules` + re-imports the same paths from another nixpkgs checkout |

`myLib/default.nix` is just the import list (with the usual commented `# ./default.nix` marker omitted here — this
directory is the one place that has a clean list).

## `mkEndpointOpt` — the important one

Used by `nixos-base/services/systemd-socket-proxyd.nix` and every file in `nixos-base/services/sleep-on-idle/`.
It is a *function that returns `mkOption`s*, relied on via the `//` operator:

```nix
origin = mkEndpointOpt { cfg = cfg.origin; ipv6-brackets = false; } // {
  serviceName = mkOption { type = types.singleLineStr; };
};
```

Semantics:

- `port` — `nullOr port`, default `null`.
- `host` — `singleLineStr`, default `"::1"` (loopback by default; nothing listens on `0.0.0.0` unless asked).
- `ip-socket` — computed as `"${host}:${port}"` when `port != null`, else `default-ip-socket`; the result is passed
  through `apply`, which is `bracketIpv6` when `ipv6-brackets = true` and `unbracketIpv6` when `false`.
- The `assert (ipv6-brackets == true) || (ipv6-brackets == false);` exists because the flag is threaded as a plain
  function argument rather than a typed option.

**Bracket rule of thumb used throughout the repo:**

| Consumer | `ipv6-brackets` | Why |
| --- | --- | --- |
| `systemd.sockets.*.listenStreams` (proxy side) | `true` | systemd socket syntax needs `[::1]:8080` |
| `systemd-socket-proxyd` ExecStart target (origin side) | `false` | the binary takes `host:port` with a literal v6 address |
| `curl` URLs in `sleep-on-idle/proxy.nix` health checks | `true` | it is a URL |
| Caddy `reverse_proxy` unix sockets | n/a | handled separately via `unix/…` prefixes |

If you get this wrong the failure mode is silent-ish: systemd parses `::1:8080` as an invalid address, or curl resolves
`[::1]:8080` correctly while `systemd-socket-proxyd` refuses the bracketed form.

## Gotchas

- These helpers live on **`pkgs`**, not on `lib`. In a module you must write `inherit (pkgs) myLib;` (see
  `sleep-on-idle/options.nix`), or `pkgs.myLib.<fn>`. `lib` is untouched — a commented-out `lib.extend` block in
  `laptop-base/common/nixpkgs-overlays.nix` shows an experiment in that direction that was abandoned.
- `splitLastColon` on a bracketed address (`[::1]:80`) returns `host = "[::1]"`, `port = "80"` — bracketing is *not*
  stripped, which is exactly what `bracketIpv6` expects (it is idempotent) and what `unbracketIpv6` undoes.
- `replaceModules` is currently **unused** by any module in the tree; it is kept for future dual-nixpkgs work
  (commented usage in `laptop-base/common/nixpkgs-overlays.nix` references `final.pkgs-2611.lib`).
- Because everything is an overlay on `nixpkgs`, importing `myLib` twice (laptop path does) is a no-op but does add the
  overlay twice in some evaluation traces — harmless, just noisy in `--show-trace`.

## How to extend

Add `myLib/<name>.nix` following the shape of `splitLastColon.nix` (an `overrideScope` that adds exactly one
attribute), then list it in `myLib/default.nix`. Keep functions pure and `lib`-based — no `pkgs` references, otherwise
the scope becomes self-referential.

## See also

- [`../nixos-base/services/HANDOVER.md`](../nixos-base/services/HANDOVER.md) — the two consumers
- [`../nixos-base/services/sleep-on-idle/HANDOVER.md`](../nixos-base/services/sleep-on-idle/HANDOVER.md)
- [`../myPkgs/HANDOVER.md`](../myPkgs/HANDOVER.md) — the sibling scope, built the same way
