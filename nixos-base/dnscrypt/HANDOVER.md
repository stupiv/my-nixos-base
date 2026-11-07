- This is the handover for `nixos-base/dnscrypt/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It provides system-wide **encrypted DNS with DNSSEC, no logging, and an OISD blocklist** via `services.dnscrypt-proxy`.
    - It is imported unconditionally from `nixos-base/default.nix` as `./dnscrypt` and is on by default via `myOpt.dnscrypt.enable = true`, so every machine using either flake output gets it.
    - `dnscrypt/default.nix` imports three files:
      - `../ipv6.nix`, which is re-imported here too and is harmless because module imports are idempotent.
      - `./dnscrypt.nix`, which holds the service and its options.
      - `./filter.nix`, which pulls the OISD blocklist from the `oisd` flake input.

  - Files
    - `default.nix` is the import list with the usual `# ./default.nix` marker.
    - `dnscrypt.nix` declares `options.myOpt.dnscrypt` and the `services.dnscrypt-proxy` configuration.
    - `filter.nix` sets `myOpt.dnscrypt.filter = readFile (inputs.oisd + /domainswild_big.txt)`.

  - Options
    - `myOpt.dnscrypt.enable` is a bool defaulting to **`true`** and turns the whole thing off when unset.
    - `myOpt.dnscrypt.ipv6.disable` is a bool with *(no default)* that sets `block_ipv6` **and** flips Cloudflared's `edgeIPVersion` to `4`.
    - `myOpt.dnscrypt.filter` is of type lines, defaults to `''''` (the empty string), and holds extra blocked names that `filter.nix` sets to the OISD list.

  - The service configuration, and why each line matters
    - The module sets `networking.networkmanager.dns = "none";` with the source comment "NM must not listen on 0.0.0.0:53".
    - It configures `services.dnscrypt-proxy.settings` with `sources.public-resolvers` carrying `urls`, `minisign_key` and `cache_file = /var/lib/dnscrypt-proxy/…`.
    - It sets `block_ipv6 = cfg.ipv6.disable;`, `ipv6_servers = true;` and `listen_addresses = [ "127.0.0.1:53" "[::1]:53" ];`.
    - It sets `require_dnssec = true;`, `require_nolog = false;` and `require_nofilter = true;`.
    - It sets `blocked_names.blocked_names_file = writeText "filter.txt" cfg.filter;`.
    - **`networkmanager.dns = "none"` is mandatory**, because without it NM rewrites `/etc/resolv.conf` and binds its own dnsmasq on `0.0.0.0:53`, which collides with dnscrypt-proxy.
    - **`listen_addresses` are loopback-only on purpose**, and the comment in the source says `[::]:53` *"will cause podman dns to fail"* because Podman's aardvark-dns wants to bind the wildcard on the same port, so do not "simplify" this to `[::]:53`.
    - **`require_nofilter = true` plus `require_dnssec = true`** are the two quality gates on the upstream resolver pool, while `require_nolog = false` is a deliberate relaxation because very few resolvers satisfy all three.
    - **`block_ipv6` is tied to `myOpt.dnscrypt.ipv6.disable`**, which has *no default*, so every host must set it.
      - It is also read by `services/cloudflared.nix` to choose `edgeIPVersion`, so a host that disables v6 must route Cloudflared over v4 or tunnels come up and never connect.
    - The resolver list is fetched at **runtime** from two URLs (GitHub raw plus a mirror), verified with the DNSCrypt minisign key, and cached under `/var/lib/dnscrypt-proxy/`.
      - First boot therefore needs outbound HTTPS and the box does not resolve anything until that fetch succeeds, and nothing in the flake pins the list contents.
    - `filter.nix` `readFile`s `domainswild_big.txt` from the `oisd` **flake input** marked `flake = false` in `flake.nix`, so the blocklist is pinned by `flake.lock` and bumping it means `nix flake update oisd` rather than editing a file.

  - Gotchas
    - **Ordering versus Cloudflared** is handled by `services/cloudflared.nix`, which adds `requires`/`after = dnscrypt-proxy.service` to every tunnel unit precisely because the tunnel resolves its edge over this resolver.
    - **Everything on the box depends on this**, so if dnscrypt-proxy fails, `nss-lookup` failures cascade into Caddy, Squid and every container, and the symptom is usually "nothing resolves" rather than "DNS is broken".
    - **`ipv6_servers = true` with `block_ipv6 = true`** looks contradictory but is not, because the first allows v6 *upstream* resolvers while the second rejects AAAA lookups, and both can be true at once.
    - **The filter file is a `writeText` in the Nix store**, so it is world-readable and part of the system closure, and you must not put anything secret in `myOpt.dnscrypt.filter`.
    - `../ipv6.nix` is imported from both `nixos-base/default.nix` and here, and since it only declares options and a `mkIf` the duplication is cosmetic and follows the repo pattern of keeping subdirectories self-contained.

  - How to extend
    - For extra blocked domains, append to `myOpt.dnscrypt.filter`, which concatenates with the OISD list because `filter.nix` uses a plain string interpolation.
    - For a different resolver policy, override `services.dnscrypt-proxy.settings`, or set `myOpt.dnscrypt.enable = false` and configure something else.
      - Note that `networkmanager.dns = "none"` disappears with it, so NM goes back to managing resolv.conf.
    - For a new upstream source, add to `sources.public-resolvers.urls` and keep the minisign key in sync.

  - See also
    - [`../../HANDOVER.md`](../../HANDOVER.md) lists the mandatory values, including `ipv6.disable`.
    - [`../services/HANDOVER.md`](../services/HANDOVER.md) covers `cloudflared.nix`, which consumes `ipv6.disable`.
    - [`../HANDOVER.md`](../HANDOVER.md) covers `ipv6.nix` and `networkmanager.nix`.
