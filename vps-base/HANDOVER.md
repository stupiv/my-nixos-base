- This is the handover for `vps-base/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It is the **server flavour** of the flake and is deliberately almost empty.
    - `vps-base/default.nix` is the entire file and contains only `imports = [ ../myPkgs ../nixos-base ];`.
    - It is exported as `flake.nixosModules.vps-base`.
    - Everything a VPS actually runs comes from `nixos-base`, while the host config is expected to add the workload (`myOpt.keycloak`, `myOpt.cloudflared`, `myOpt.proxy-compose`, …) and the `install/` layer.

  - Why it imports `../myPkgs` when `nixos-base` already does
    - `nixos-base/default.nix` imports both `../myLib` and `../myPkgs`, so the line here is redundant.
    - It is kept as documentation of intent, namely "a VPS gets the pinned image tags".
    - Module imports are idempotent, so this costs nothing at evaluation time.
    - If you tidy it away, put the reasoning in the commit message rather than silently dropping it.

  - What a VPS host still has to provide
    - `vps-base` supplies **no defaults** for these, and evaluation fails without them.
    - `myOpt.admin.username`, `hashedPassword` and `authorizedKeys` are required, and `authorizedKeys != null` is what turns SSH on.
    - `myOpt.openssh.port` is required if `enable = true`, because the module writes `ports = [cfg.port]` while the default is `null` (**G5**).
    - `myOpt.openssh.cloudflared.{tunnel-id,hostname}` is needed only if SSH should be reachable through a tunnel instead of a public port.
    - `myOpt.ipv6.public-address`, `.interface` and `.gateway` accept `null` to mean "no static v6 config".
    - `myOpt.dnscrypt.ipv6.disable` drives `block_ipv6` **and** Cloudflared `edgeIPVersion` (`4` vs `6`).
    - `system.stateVersion` is not set anywhere in the repo.
    - `myOpt.disk.*` plus `./install` are needed if you deploy with disko/nixos-anywhere.
    - sops secrets such as `<instance>/litellm-envFile`, `<instance>/frappe_envfile` and `<instance>/tunnel-credentials` must exist in the consumer's sops file.
    - Because `authorizedKeys` also gates `myOpt.openssh.enable` via `admin.nix`, a VPS configured with a password only gets a user with **no** SSH server and **no** `AllowUsers` list.
      - For a headless box that is the classic "locked out" trap, so set `authorizedKeys` *before* the first `switch`.

  - Typical workload stack on this flavour
    - The modules are written for a chain that starts at the Internet and ends at an egress proxy:
      - A cloudflared tunnel (`services/cloudflared.nix`, `myOpt.cloudflared`) is the only ingress.
      - It forwards to the unix socket `/run/proxy-compose/<name>/<name>.sock`.
      - Caddy (`services/proxy-compose.nix`) terminates that socket.
      - Caddy points at a sleep-on-idle proxy socket from `services/sleep-on-idle/`.
      - The proxy wakes an app container or NixOS container running in its own netns.
      - Outbound traffic from that namespace goes through the squid egress proxy (`services/squid.nix`), which is outbound only.
    - Nothing in that chain bakes in a port on `0.0.0.0`, and the Cloudflared path has no listening TCP port at all, which is why `laptop-base/firewall.nix` can turn `services.caddy.openFirewall` off unconditionally.

  - Gotchas
    - **No `nixpkgs.hostPlatform`** is set here, so the host config decides between the flake's `x86_64-linux` and `aarch64-linux` systems.
    - **No hostname, no firewall, no timezone** are set here either.
      - `nixos-base/time.nix` hard-codes `Asia/Ho_Chi_Minh` and `LC_TIME = en_DK.UTF-8` (**G8**), which is fine for the author's setup but suspicious on a rented VPS in another region, so override with `mkForce` if needed.
    - **`swapDevices = mkForce []`** in `zramSwap.nix` means a VPS with a small RAM allocation will OOM rather than swap to disk.
      - Keeping it that way is a deliberate policy, and changing it means overriding both `swapDevices` and `zramSwap.writebackDevice`.
    - **The Podman backend is assumed but not enabled here.**
      - `virtualisation.oci-containers.backend = "podman"` is set inside the individual service modules such as `camofox.nix` and `frappe-compose.nix`, while `nixos-base/podman.nix` only sets `autoPrune`.
      - If you add a new container module, set the backend there too.
    - The bare-metal counterpart is `laptop-base`, and the difference is *only* the desktop/hardware layer, so a service module that works on one should work on the other.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers architecture, mandatory values and global issues.
    - [`../nixos-base/HANDOVER.md`](../nixos-base/HANDOVER.md) covers everything that actually runs.
    - [`../laptop-base/HANDOVER.md`](../laptop-base/HANDOVER.md) covers the other flavour.
