1. `vps-base/` exports the minimal server flavour as `flake.nixosModules.vps-base`.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. `default.nix` imports only `../myPkgs` and `../nixos-base`.
        1. The explicit package-scope import is redundant with the shared layer but documents intent.
        2. Repeated module imports are deduplicated.
        3. The host adds workloads and the installation layer separately.
    3. Hosts must supply identity, networking, and deployment values.
        1. Set `myOpt.admin.username`, `hashedPassword`, and `authorizedKeys` explicitly.
        2. Non-null authorized keys enable SSH by default, while a password-only configuration can leave a headless host inaccessible.
        3. Set `myOpt.openssh.port` whenever SSH is enabled to avoid **G5**.
        4. Set `myOpt.openssh.cloudflared.tunnel-id` and `hostname` only for tunnel-based SSH.
        5. Configure `myOpt.ipv6.public-address`, `interface`, and `gateway`, using supported null values when static IPv6 is unwanted.
        6. Set `myOpt.dnscrypt.ipv6.disable` to select DNS IPv6 blocking and Cloudflared transport.
        7. Provide `system.stateVersion`, `nixpkgs.hostPlatform`, and `networking.hostName` downstream.
        8. Supply disk options and import `install/` when deploying with disko or nixos-anywhere.
        9. Provision workload sops keys such as `<instance>/litellm-envFile`, `<instance>/frappe_envfile`, and `<instance>/tunnel-credentials`.
    4. A typical tunneled workload uses a socket-based ingress chain.
        1. Cloudflared forwards to `/run/proxy-compose/<name>/<name>.sock`.
        2. Caddy forwards requests to a sleep-on-idle socket.
        3. The proxy wakes the application container inside its isolated network namespace.
        4. Squid provides explicitly allowed outbound access.
        5. This tunnel path requires no public application TCP listener.
    5. Shared policies still apply to VPS hosts.
        1. Override the inherited `Asia/Ho_Chi_Minh` timezone and `en_DK.UTF-8` time locale when inappropriate under **G8**.
        2. Account for 400 percent zram and forced empty disk swap under **G9**.
        3. Revising disk-swap policy requires reviewing both `swapDevices` and `zramSwap.writebackDevice`.
        4. OCI service modules select the Podman backend individually rather than relying on this entry point.
        5. The shared Podman module configures automatic pruning rather than global workload backend selection.
        6. Laptop and VPS flavours share service modules and differ mainly in desktop and hardware additions.
    6. Read the related handovers before deployment.
        1. The [root handover](../HANDOVER.md) lists mandatory values and global issues.
        2. The [shared-system handover](../nixos-base/HANDOVER.md) describes inherited policy and services.
        3. The [laptop handover](../laptop-base/HANDOVER.md) describes workstation-specific additions.
