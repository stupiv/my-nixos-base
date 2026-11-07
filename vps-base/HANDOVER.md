# HANDOVER — `vps-base/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

The **server flavour** of the flake. It is deliberately almost empty:

```nix
# vps-base/default.nix — the entire file
{
  imports = [
    ../myPkgs
    ../nixos-base
  ];
}
```

Exported as `flake.nixosModules.vps-base`. Everything a VPS actually runs comes from `nixos-base`; the host config is
expected to add the workload (`myOpt.keycloak`, `myOpt.cloudflared`, `myOpt.proxy-compose`, …) and the `install/` layer.

## Why it imports `../myPkgs` when `nixos-base` already does

`nixos-base/default.nix` imports both `../myLib` and `../myPkgs`, so the line here is redundant. It is kept as
documentation of intent ("a VPS gets the pinned image tags"). Module imports are idempotent, so this costs nothing at
evaluation time — but if you tidy it away, put the reasoning in the commit message rather than silently dropping it.

## What a VPS host still has to provide

`vps-base` supplies **no defaults** for these; evaluation fails without them (see root handover §5):

| Option | Note |
| --- | --- |
| `myOpt.admin.username` / `hashedPassword` / `authorizedKeys` | `authorizedKeys != null` is what turns SSH on |
| `myOpt.openssh.port` | if `enable = true` — `ports = [cfg.port]` and the default is `null` (**G5**) |
| `myOpt.openssh.cloudflared.{tunnel-id,hostname}` | only if SSH should be reachable through a tunnel instead of a public port |
| `myOpt.ipv6.public-address`, `.interface`, `.gateway` | `null` means "no static v6 config" |
| `myOpt.dnscrypt.ipv6.disable` | drives `block_ipv6` **and** Cloudflared `edgeIPVersion` (`4` vs `6`) |
| `system.stateVersion` | not set anywhere in the repo |
| `myOpt.disk.*` + `./install` | if you deploy with disko/nixos-anywhere |
| sops secrets | `<instance>/litellm-envFile`, `<instance>/frappe_envfile`, `<instance>/tunnel-credentials`, … |

Because `authorizedKeys` also gates `myOpt.openssh.enable` (via `admin.nix`), a VPS configured with a password only
gets a user with **no** SSH server and **no** `AllowUsers` list. For a headless box that is the classic "locked out"
trap: set `authorizedKeys` *before* the first `switch`.

## Typical workload stack on this flavour

The composition the modules are written for:

```
Internet
  └── cloudflared tunnel  (services/cloudflared.nix, myOpt.cloudflared)
        └── unix socket /run/proxy-compose/<name>/<name>.sock
              └── caddy  (services/proxy-compose.nix)
                    └── sleep-on-idle proxy socket  (services/sleep-on-idle/)
                          └── app container/NixOS container, in its own netns
                                └── squid egress proxy (services/squid.nix)  [outbound only]
```

Nothing in that chain bakes in a port on `0.0.0.0`; the Cloudflared path has no listening TCP port at all, which is why
`laptop-base/firewall.nix` can turn `services.caddy.openFirewall` off unconditionally.

## Gotchas

- **No `nixpkgs.hostPlatform`.** The flake's `systems` are `x86_64-linux` and `aarch64-linux`; the host config decides.
- **No hostname, no firewall, no timezone.** `nixos-base/time.nix` hard-codes `Asia/Ho_Chi_Minh` and `LC_TIME = en_DK.UTF-8`
  (**G8**) — fine for the author's setup, suspicious on a rented VPS in another region. Override with `mkForce` if needed.
- **`swapDevices = mkForce []`** (`zramSwap.nix`) — a VPS with a small RAM allocation will OOM rather than swap to disk.
  Keeping it that way is a deliberate policy; changing it means overriding both `swapDevices` and `zramSwap.writebackDevice`.
- **Podman backend is assumed but not enabled here.** `virtualisation.oci-containers.backend = "podman"` is set inside
  the individual service modules (e.g. `camofox.nix`, `frappe-compose.nix`); `nixos-base/podman.nix` only sets
  `autoPrune`. If you add a new container module, set the backend there too.
- The bare-metal counterpart is `laptop-base`; the difference is *only* the desktop/hardware layer, so a service module
  that works on one should work on the other.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — architecture, mandatory values, global issues
- [`../nixos-base/HANDOVER.md`](../nixos-base/HANDOVER.md) — everything that actually runs
- [`../laptop-base/HANDOVER.md`](../laptop-base/HANDOVER.md) — the other flavour
