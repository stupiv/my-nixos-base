1. `nixos-base/dnscrypt/` provides encrypted DNS with DNSSEC and an OISD blocklist.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. `default.nix` imports the shared IPv6 module, `dnscrypt.nix`, and `filter.nix`.
        1. Reimporting `../ipv6.nix` is deduplicated by the module system.
        2. Keep the commented self-import marker.
    3. Hosts must configure the DNS options explicitly where required.
        1. `myOpt.dnscrypt.enable` defaults to `true`.
        2. `myOpt.dnscrypt.ipv6.disable` has no default and controls `block_ipv6`.
        3. Cloudflared also reads that flag to select edge IP version 4 or 6.
        4. `myOpt.dnscrypt.filter` is a lines option with an empty-string default.
        5. `filter.nix` reads `domainswild_big.txt` from the non-flake `oisd` input into the filter.
    4. Resolver configuration separates local listeners from upstream policy.
        1. NetworkManager uses `dns = "none"` so it does not manage the resolver path independently.
        2. DNSCrypt listens only on `127.0.0.1:53` and `[::1]:53`.
        3. Avoid wildcard listeners because the source warns of conflicts with Podman's DNS.
        4. `require_dnssec = true` and `require_nofilter = true` constrain upstream resolvers.
        5. `require_nolog = false` does not require upstream no-logging guarantees.
        6. `ipv6_servers = true` permits IPv6 upstreams independently of AAAA blocking.
        7. `blocked_names_file` references a `writeText` file containing the configured filter.
    5. Resolver lists and domain filters have different update mechanisms.
        1. Public resolver lists download at runtime from two URLs with minisign verification.
        2. Their cache lives under `/var/lib/dnscrypt-proxy/` rather than in the flake lock.
        3. First-boot resolver downloads require outbound HTTPS.
        4. OISD content is pinned by `flake.lock` and updated with `nix flake update oisd`.
        5. Store-backed filter content is world-readable and must not contain secrets.
    6. DNS failure affects dependent services broadly.
        1. Cloudflared units require and follow `dnscrypt-proxy.service`.
        2. Resolver failures can cascade into Caddy, Squid, and containers.
        3. Disabling the module also removes its NetworkManager DNS override.
    7. Extend DNS policy through the existing options.
        1. Add blocked domains through the lines-valued `myOpt.dnscrypt.filter`.
        2. Override `services.dnscrypt-proxy.settings` for resolver policy changes.
        3. Keep source URLs and their minisign keys consistent when adding resolver sources.
    8. Read the related handovers for shared option consumers.
        1. The [root handover](../../HANDOVER.md) lists mandatory IPv6 values.
        2. The [services handover](../services/HANDOVER.md) describes Cloudflared.
        3. The [shared-system handover](../HANDOVER.md) covers IPv6 and NetworkManager.
