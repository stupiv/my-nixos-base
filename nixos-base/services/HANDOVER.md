1. `nixos-base/services/` provides opt-in workloads and reusable service primitives.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. `default.nix` imports the service modules, [`compose/`](compose/HANDOVER.md), and [`sleep-on-idle/`](sleep-on-idle/HANDOVER.md).
    3. Five primitives define most workload composition.
        1. `netns.nix` creates isolated network namespaces through `myOpt.netns.<name>`.
            1. Namespace units create a short hashed namespace name and bring up loopback.
            2. `set-network-namespace.systemd-services` sets `NetworkNamespacePath`, hides resolver paths, and binds units to namespace lifetime.
            3. OCI targets use `networks = ["ns:/run/netns/<ns>"]`, while NixOS containers use `networkNamespace`.
            4. Namespace setup is sandboxed with administrative capabilities restricted to its task.
            5. Maintainer intent explicitly excludes direct DNS and Internet access inside these namespaces.
            6. **G1** is resolved for Camofox, Fastcrw, and LiteLLM by moving namespace and cgroup wiring into compose modules.
            7. Old helpers expected `path`, `resolvConf`, and `unit` instead of the actual `nsPath` and `serviceUnit` options.
        2. `systemd-socket-proxyd.nix` bridges listening sockets to origin endpoints.
            1. Instances declare `origin` and `proxy` using [`mkEndpointOpt`](../../myLib/HANDOVER.md).
            2. Origins use unbracketed endpoint syntax and listeners use bracketed IPv6.
            3. Per-instance drop-ins extend the shared `systemd-socket-proxyd@` socket and service templates.
            4. Socket units join `sockets.target`, while proxy services require and follow the origin service.
        3. `sleep-on-idle/` combines socket activation, readiness checks, and slice freezing.
            1. Its proxy runs `systemd-socket-proxyd --exit-idle-time` after the health check succeeds.
            2. The [sleep-on-idle handover](sleep-on-idle/HANDOVER.md) explains the freeze and thaw lifecycle.
        4. `squid.nix` provides allowlisted egress through isolated proxy instances.
            1. Squid listens inside a namespace and is reached through socket proxies.
            2. `set-env-vars` injects proxy environment variables into selected systemd, OCI, or NixOS-container targets.
            3. Default egress restrictions permit only HTTPS CONNECT requests to configured FQDNs on port 443.
            4. Default build-time validation runs `squid -k parse` and rejects invalid configuration.
            5. Hardened `squid@` units use dynamic users, strict filesystem protection, restricted capabilities, and `UMask = 0077`.
            6. Each template instance requires `/etc/squid/<name>.conf` generated through `environment.etc`.
        5. `proxy-compose.nix` publishes an application through Caddy and sleep-on-idle.
            1. Optional Cloudflared ingress targets a unix socket.
            2. Local mode and Cloudflared mode are mutually exclusive by assertion.
            3. Read-only `cloudflared.enable` derives from nonempty `modules.cloudflared`.
            4. Caddy unix-socket origins receive the required `unix/` prefix.
            5. Firewall opening applies only when neither local mode nor Cloudflared mode is selected.
    4. Application modules expose instance-specific configuration.
        1. `camofox.nix` runs headless Firefox in Podman with read-only storage, dropped capabilities, and no-new-privileges.
            1. It reserves 2 GiB of shared memory and limits processes to 512.
            2. Options include telemetry, socket-safe URLs, optional sops environment files, and OCI-container pass-throughs.
        2. `fastcrw.nix` creates hardened `fastcrw@` native systemd units with per-instance drop-ins.
            1. Instances require an explicit package and default to `autoStart = false`.
            2. Options include environment files, sops integration, normalized URLs, and systemd-service pass-throughs.
        3. `hermes-agent.nix` configures the agent inside an existing NixOS container.
            1. Options cover identity, state, host and port, environment, settings, and `modules.services.hermes-agent`.
            2. Its read-only unix socket defaults to `<shared-run-dir>/hermes-agent.sock`.
            3. Settings merge Firecrawl backends, Camofox browser integration, `busy_input_mode = "steer"`, custom-provider model fields, and disabled default MoA.
            4. Container configuration imports upstream Hermes and a socket bridge with matching UID/GID and service hardening.
        4. `litellm.nix` configures LiteLLM inside an existing NixOS container.
            1. Options cover service pass-throughs, container metadata, state, telemetry, settings, environment, and endpoint fields.
            2. It bridges `<shared-run-dir>/litellm.sock` to `services.litellm` and computes a bracket-safe read-only URL.
            3. Service hardening uses `ProtectSystem = "strict"` with `ReadWritePaths = [stateDir]`.
            4. Compose modules own host containers, tmpfiles, sops, namespaces, and sleep-on-idle integration.
        5. `keycloak.nix` runs Keycloak inside a NixOS container behind a unix-socket bridge.
            1. It forces `http-host = ::1`, `http-port = 25546`, and `proxy-headers = xforwarded`.
            2. Database type, host, and local-creation settings pass through from configuration.
        6. `valkey.nix` enables `services.redis` with a Valkey package inside the named container.
        7. `mariadb.nix` enables `services.mysql` with state under `<container.stateDir>/mariadb`.
        8. `postgresql.nix` enables PostgreSQL and creates its state directory with mode `0700` and PostgreSQL ownership.
        9. `searxng.nix` configures `services.searx` inside a NixOS container.
            1. It requires a package, exposes `settings.server.port`, accepts freeform service configuration, and strips `_module`.
        10. `cloudflared.nix` creates tunnels using sops credentials and configured ingress.
            1. Tunnels default to `http_status:404`, depend on DNSCrypt, select edge IP version from DNS policy, and use stepped restart backoff.
        11. `rclone-automount.nix` creates network filesystems using systemd automount.
            1. Defaults include full VFS caching, a 90-day maximum cache age, 20 GiB minimum free space, and admin UID/GID.
            2. Mount options include `allow_other`, `nofail`, and `_netdev`.
    5. Shared idioms determine activation and persistence.
        1. Service instances usually default to enabled and are filtered through `cfg.enable`.
        2. Application URLs use `pkgs.myLib.bracketIpv6` rather than copied URL helpers.
        3. Declare sops keys as `<instance>/<purpose>` and provision actual secrets downstream.
        4. `autoStart = false` usually means the workload waits for socket activation rather than malfunctioning.
        5. OCI modules must select the Podman backend explicitly.
        6. Renaming instances can orphan state, sockets, namespace identifiers, and secret references.
        7. Weakly typed pass-throughs defer many configuration errors until attributes are forced.
        8. Custom LiteLLM state locations require compatible writable-path and directory rules.
        9. **⚠ verify** rclone's literal `.cache/rclone/myOpt.rclone.automount` cache-directory default.
        10. **G6** marks the unfinished n8n compose option reads.
    6. Add new services by following the closest active implementation.
        1. Use Fastcrw for native units, Camofox for OCI workloads, and Keycloak or LiteLLM for container-inner services.
        2. Declare `myOpt.<service>` as instance submodules and guard generated configuration with `mkIf (enabled != {})`.
        3. Prefer unix sockets and compose-owned namespace, cgroup, and publication wiring.
        4. Register new modules in the existing `default.nix` import list without removing comment markers.
    7. Read the related handovers for contracts outside this directory.
        1. The [shared-system handover](../HANDOVER.md) covers sops and global system policy.
        2. The [root handover](../../HANDOVER.md) records **G1**, **G6**, and maintenance entry points.
        3. The [library handover](../../myLib/HANDOVER.md) describes endpoint and IPv6 helpers.
