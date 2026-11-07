# HANDOVER — `nixos-base/dnscrypt/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

System-wide **encrypted DNS with DNSSEC, no logging, and an OISD blocklist**, via `services.dnscrypt-proxy`.
It is imported unconditionally from `nixos-base/default.nix` (`./dnscrypt`), and it is on by default
(`myOpt.dnscrypt.enable = true`), so every machine using either flake output gets it.

```
dnscrypt/default.nix
├── ../ipv6.nix        (re-imported here too — harmless, module imports are idempotent)
├── ./dnscrypt.nix     (the service + options)
└── ./filter.nix       (pulls the OISD blocklist from the `oisd` flake input)
```

## Files

| File | Role |
| --- | --- |
| `default.nix` | import list, with the usual `# ./default.nix` marker |
| `dnscrypt.nix` | `options.myOpt.dnscrypt` + the `services.dnscrypt-proxy` configuration |
| `filter.nix` | `myOpt.dnscrypt.filter = readFile (inputs.oisd + /domainswild_big.txt)` |

## Options

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `myOpt.dnscrypt.enable` | bool | **`true`** | turn the whole thing off |
| `myOpt.dnscrypt.ipv6.disable` | bool | *(no default)* | sets `block_ipv6` **and** flips Cloudflared's `edgeIPVersion` to `4` |
| `myOpt.dnscrypt.filter` | lines | `''''` (empty) | extra blocked names; `filter.nix` sets it to the OISD list |

## The service configuration, and why each line matters

```nix
networking.networkmanager.dns = "none";   # NM must not listen on 0.0.0.0:53
services.dnscrypt-proxy.settings = {
  sources.public-resolvers = { urls = [ GitHub + network.info mirror ]; minisign_key = …; cache_file = /var/lib/dnscrypt-proxy/…; };
  block_ipv6      = cfg.ipv6.disable;
  ipv6_servers    = true;
  listen_addresses = [ "127.0.0.1:53" "[::1]:53" ];   # NOT [::]:53
  require_dnssec  = true;
  require_nolog   = false;
  require_nofilter = true;
  blocked_names.blocked_names_file = writeText "filter.txt" cfg.filter;
};
```

- **`networkmanager.dns = "none"` is mandatory.** Without it NM rewrites `/etc/resolv.conf` and binds its own
  dnsmasq on `0.0.0.0:53`, which collides with dnscrypt-proxy.
- **`listen_addresses` are loopback-only on purpose.** The comment in the source says `[::]:53` *"will cause podman dns
  to fail"* — Podman's aardvark-dns wants to bind the wildcard on the same port. Do not "simplify" this to `[::]:53`.
- **`require_nofilter = true` + `require_dnssec = true`** are the two quality gates on the upstream resolver pool;
  `require_nolog = false` is a deliberate relaxation (very few resolvers satisfy all three).
- **`block_ipv6` is tied to `myOpt.dnscrypt.ipv6.disable`**, which has *no default*. Every host must set it. It is also
  read by `services/cloudflared.nix` to choose `edgeIPVersion` — a host that disables v6 must route Cloudflared over
  v4 or tunnels come up and never connect.
- The resolver list is fetched at **runtime** from two URLs (GitHub raw + a mirror), verified with the DNSCrypt
  minisign key, and cached under `/var/lib/dnscrypt-proxy/`. So first boot needs outbound HTTPS, and the box does not
  resolve anything until that fetch succeeds. Nothing in the flake pins the list contents.
- `filter.nix` `readFile`s `domainswild_big.txt` from the `oisd` **flake input** (`flake = false` in `flake.nix`), so the
  blocklist is pinned by `flake.lock` — bumping the list means `nix flake update oisd`, not editing a file.

## Gotchas

- **Ordering vs. Cloudflared.** `services/cloudflared.nix` adds `requires`/`after = dnscrypt-proxy.service` to every
  tunnel unit, precisely because the tunnel resolves its edge over this resolver.
- **Everything on the box depends on this.** If dnscrypt-proxy fails, `nss-lookup` failures cascade into Caddy, Squid and
  every container. Symptom is usually "nothing resolves" rather than "DNS is broken".
- **`ipv6_servers = true` with `block_ipv6 = true`** looks contradictory but is not: the first allows v6 *upstream*
  resolvers, the second rejects AAAA lookups. Both can be true at once.
- **The filter file is a `writeText` in the Nix store**, i.e. world-readable and part of the system closure. Do not put
  anything secret in `myOpt.dnscrypt.filter`.
- `../ipv6.nix` is imported from both `nixos-base/default.nix` and here; it only declares options and a `mkIf`, so the
  duplication is cosmetic (it is the pattern this repo uses to keep subdirectories self-contained).

## How to extend

- Extra blocked domains → append to `myOpt.dnscrypt.filter` (concatenates with the OISD list because `filter.nix` uses a
  plain string interpolation).
- Different resolver policy → override `services.dnscrypt-proxy.settings`, or set `myOpt.dnscrypt.enable = false` and
  configure something else; note `networkmanager.dns = "none"` disappears with it, so NM goes back to managing resolv.conf.
- New upstream source → add to `sources.public-resolvers.urls`; keep the minisign key in sync.

## See also

- [`../../HANDOVER.md`](../../HANDOVER.md) — §5 mandatory values (`ipv6.disable`)
- [`../services/HANDOVER.md`](../services/HANDOVER.md) — `cloudflared.nix` consumes `ipv6.disable`
- [`../HANDOVER.md`](../HANDOVER.md) — `ipv6.nix`, `networkmanager.nix`
