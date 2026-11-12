1. `nixos-base/unmaintained/2511/` preserves Caddy option compatibility for older nixpkgs pins.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../HANDOVER.md).
    2. `default.nix` imports `caddy.nix`, but the inactive parent keeps the shim outside the live graph.
        1. The directory name refers to the NixOS 25.11 option boundary.
    3. `caddy.nix` declares three `services.caddy` options.
        1. `openFirewall` is boolean and defaults to `false`.
        2. `httpPort` is nullable and defaults to 80.
        3. `httpsPort` is nullable and defaults to 443.
        4. Enabled firewall opening allows non-null HTTP and HTTPS TCP ports.
        5. UDP allows only the non-null HTTPS port for HTTP/3.
    4. The shim must not overlap upstream declarations.
        1. The pinned NixOS 26.05 module already provides these options.
        2. Importing both implementations risks conflicting option declarations.
        3. Older pins need equivalent options for proxy-compose and laptop firewall settings.
        4. Preserve the TCP and UDP distinction rather than assigning identical port lists.
        5. Retain the `lib` and `types` scope when copying nullable-port declarations.
        6. Remove the corresponding entry-point import if deleting the shim.
    5. Read the related handovers before changing compatibility behavior.
        1. The [parent handover](../HANDOVER.md) explains why this subtree is inactive.
        2. The [shared-system handover](../../HANDOVER.md) describes the active Caddy NSS-path fix.
        3. The [laptop handover](../../../laptop-base/HANDOVER.md) describes `services.caddy.openFirewall = false`.
