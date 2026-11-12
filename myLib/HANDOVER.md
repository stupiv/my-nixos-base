1. `myLib/` exposes pure helpers through `pkgs.myLib` rather than `lib` or a dedicated flake output.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. Overlay modules build and extend one shared scope.
        1. `base.nix` creates an empty scope with `makeScope` and orders it first with `mkBefore`.
        2. Other modules add attributes with `prev.myLib.overrideScope`.
        3. `default.nix` registers the helper modules without the usual commented self-import marker.
        4. Import this directory or `nixos-base` to make the scope available.
        5. Consumers use `inherit (pkgs) myLib` or `pkgs.myLib.<helper>`.
    3. Address helpers normalize endpoint syntax.
        1. `splitLastColon` uses greedy pattern `^(.*):([^:]*)$` to split the final colon.
        2. It returns `{ host, port }` with `port = null` when no colon exists.
        3. Bracketed input `[::1]:80` retains `[::1]` as its host and `80` as its port.
        4. `bracketIpv6` adds brackets around colon-containing hosts with ports while preserving already-bracketed input.
        5. `unbracketIpv6` removes brackets before a port.
        6. Raw IPv6 literals require care because their final colon can be interpreted as a port separator.
    4. `mkEndpointOpt` returns endpoint option declarations.
        1. Its arguments include `cfg`, required boolean `ipv6-brackets`, and optional `default-ip-socket = null`.
        2. `port` is nullable and defaults to `null`.
        3. `host` defaults to `::1`.
        4. `ip-socket` derives from `host:port` when a port exists and otherwise uses `default-ip-socket`.
        5. Its `apply` step brackets or unbrackets IPv6 according to the boolean argument.
        6. Callers merge the returned option set with additional declarations using `//`.
    5. Endpoint consumers depend on different bracket rules.
        1. Systemd `listenStreams` requires bracketed IPv6 such as `[::1]:8080`.
        2. `systemd-socket-proxyd` origin arguments use the repository's unbracketed endpoint form.
        3. Curl health-check URLs require bracketed IPv6.
        4. Caddy unix-socket targets use separate `unix/` prefixes.
        5. Incorrect normalization can break systemd parsing or proxy connectivity.
    6. `replaceModules` supports alternate nixpkgs module sources.
        1. It disables selected module paths and reimports matching paths from another nixpkgs checkout.
        2. No active repository module currently uses this helper.
    7. Extend the scope without introducing package recursion.
        1. Add one helper through an `overrideScope` module and register it in `default.nix`.
        2. Keep helpers pure and library-based rather than depending on packages from their own scope.
        3. Repeated imports of the same module are deduplicated by the module system.
    8. Read the related handovers for consumers and scope patterns.
        1. The [services handover](../nixos-base/services/HANDOVER.md) covers socket proxies.
        2. The [sleep-on-idle handover](../nixos-base/services/sleep-on-idle/HANDOVER.md) covers endpoint-heavy consumers.
        3. The [package-scope handover](../myPkgs/HANDOVER.md) describes the sibling overlay scope.
