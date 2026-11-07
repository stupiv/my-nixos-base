- This is the handover for `myLib/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - Six tiny overlay modules build a **custom Nix library scope** reachable as `pkgs.myLib`.
    - Nothing here is a NixOS option, and the scope exists so that service modules can write `inherit (pkgs) myLib;` and use helpers that know about IPv6 bracket rules and endpoint options.
    - `myLib/base.nix` creates the initially empty scope with `nixpkgs.overlays = lib.mkBefore [ (final: prev: { myLib = prev.lib.makeScope prev.newScope (self: {}); }) ];`.
    - Every other file then does `prev.myLib.overrideScope (ml-final: ml-prev: { … })`, so **each file adds one attribute to the same scope**.
      - Order therefore does not matter and files can be added without touching existing ones.
      - The scope must exist first, which is why `base.nix` uses `mkBefore`.
    - `nixos-base/default.nix` and `vps-base/default.nix` both import `../myLib`.
    - There is no `myLib` flake output, so a host that wants these helpers must import the directory or `nixos-base`.

  - Files
    - `base.nix` creates the scope and uses `mkBefore` so `myLib` exists for the rest.
    - `splitLastColon.nix` adds `splitLastColon : string → { host, port }`.
      - It uses `builtins.match "^(.*):([^:]*)$"`, which is greedy and therefore splits on the **last** colon, and returns `port = null` when there is no colon.
    - `bracketIpv6.nix` adds `bracketIpv6 : string → string`.
      - It leaves the string alone if it has no port, is already bracketed, or the host has no `:`, and otherwise produces `[host]:port`.
    - `unbracketIpv6.nix` adds `unbracketIpv6 : string → string` as the inverse that strips `[...]` before a port.
    - `mkEndpointOpt.nix` adds `mkEndpointOpt { cfg, ipv6-brackets, default-ip-socket ? null, ... }`, which **returns an option set** containing `port`, `host` and `ip-socket`.
    - `replaceModules.nix` adds `replaceModules : nixpkgs-x → [modulePath] → [module]`, which emits `disabledModules` and re-imports the same paths from another nixpkgs checkout.
    - `myLib/default.nix` is just the import list, and this directory is the one place with a clean list that omits the usual commented `# ./default.nix` marker.

  - `mkEndpointOpt` — the important one
    - It is used by `nixos-base/services/systemd-socket-proxyd.nix` and by every file in `nixos-base/services/sleep-on-idle/`.
    - It is a *function that returns `mkOption`s* and is relied on via the `//` operator, as in `origin = mkEndpointOpt { cfg = cfg.origin; ipv6-brackets = false; } // { serviceName = mkOption { type = types.singleLineStr; }; };`.
    - Semantics of the returned options:
      - `port` is `nullOr port` with default `null`.
      - `host` is `singleLineStr` with default `"::1"`, so loopback is the default and nothing listens on `0.0.0.0` unless asked.
      - `ip-socket` is computed as `"${host}:${port}"` when `port != null` and otherwise falls back to `default-ip-socket`.
      - The `ip-socket` result is passed through `apply`, which is `bracketIpv6` when `ipv6-brackets = true` and `unbracketIpv6` when `false`.
      - The `assert (ipv6-brackets == true) || (ipv6-brackets == false);` exists because the flag is threaded as a plain function argument rather than a typed option.
    - The bracket rule of thumb used throughout the repo:
      - `systemd.sockets.*.listenStreams` on the proxy side uses `ipv6-brackets = true`, because systemd socket syntax needs `[::1]:8080`.
      - The `systemd-socket-proxyd` ExecStart target on the origin side uses `false`, because the binary takes `host:port` with a literal v6 address.
      - `curl` URLs in `sleep-on-idle/proxy.nix` health checks use `true`, because the value is a URL.
      - Caddy `reverse_proxy` unix sockets are not applicable and are handled separately via `unix/…` prefixes.
    - If you get this wrong the failure mode is silent-ish, because systemd parses `::1:8080` as an invalid address, or curl resolves `[::1]:8080` correctly while `systemd-socket-proxyd` refuses the bracketed form.

  - Gotchas
    - These helpers live on **`pkgs`**, not on `lib`, so in a module you must write `inherit (pkgs) myLib;` as in `sleep-on-idle/options.nix`, or use `pkgs.myLib.<fn>`.
      - `lib` is untouched, and a commented-out `lib.extend` block in `laptop-base/common/nixpkgs-overlays.nix` shows an abandoned experiment in that direction.
    - `splitLastColon` on a bracketed address such as `[::1]:80` returns `host = "[::1]"` and `port = "80"`, so bracketing is *not* stripped.
      - That is exactly what `bracketIpv6` expects, since it is idempotent, and what `unbracketIpv6` undoes.
    - `replaceModules` is currently **unused** by any module in the tree and is kept for future dual-nixpkgs work.
      - The commented usage in `laptop-base/common/nixpkgs-overlays.nix` references `final.pkgs-2611.lib`.
    - Because everything is an overlay on `nixpkgs`, importing `myLib` twice as the laptop path does is a no-op but does add the overlay twice in some evaluation traces, which is harmless and merely noisy in `--show-trace`.

  - How to extend
    - Add `myLib/<name>.nix` following the shape of `splitLastColon.nix`, meaning an `overrideScope` that adds exactly one attribute.
    - Then list it in `myLib/default.nix`.
    - Keep functions pure and `lib`-based with no `pkgs` references, otherwise the scope becomes self-referential.

  - See also
    - [`../nixos-base/services/HANDOVER.md`](../nixos-base/services/HANDOVER.md) covers the two consumers.
    - [`../nixos-base/services/sleep-on-idle/HANDOVER.md`](../nixos-base/services/sleep-on-idle/HANDOVER.md) covers the heaviest consumer.
    - [`../myPkgs/HANDOVER.md`](../myPkgs/HANDOVER.md) covers the sibling scope, which is built the same way.
