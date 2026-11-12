1. `nixos-base/services/compose/` assembles multi-component applications from service primitives.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../HANDOVER.md).
    2. Active modules use two container runtimes.
        1. NixOS containers use systemd-nspawn, share the host store, and normally have ephemeral roots.
        2. OCI containers use Podman images and per-module backend selection.
        3. `default.nix` imports Frappe v16, Hermes, Keycloak, n8n, and Plausible compose modules.
        4. Keep the commented `# ./unmaintained` marker for the [dormant module shelf](unmaintained/HANDOVER.md).
    3. Compose modules share an instance-based wiring pattern.
        1. Declare `myOpt.<app>-compose` instance submodules and filter enabled instances.
        2. Wire publication through `myOpt.proxy-compose` and readiness through `myOpt.sleep-on-idle`.
        3. Attach isolated workloads through `myOpt.netns` and explicitly allowed egress through `myOpt.squid`.
        4. Place workloads in NixOS-container configs or `virtualisation.oci-containers.containers`.
        5. Declare sops secret paths without embedding secret values.
        6. Use `autoStart = false` and `set-cgroup-parent` for on-demand activation and freezing.
        7. Expose host customization through `modules.*` pass-throughs.
        8. Check explicit `mkDefault` and `mkForce` priorities rather than treating `mkMerge` ordering as an override mechanism.
    4. Plausible is the recommended NixOS-container template.
        1. `plausible-compose.nix` runs Plausible, PostgreSQL, and ClickHouse in one container.
        2. Options select each component's package and state directory.
        3. `secretKeybaseFile-key` defaults to `<name>/secretKeybaseFile`.
        4. Secret parent directories are bind-mounted read-only through `shared-run-secrets`.
        5. Dynamic-user state mounts use paths such as `/var/lib/private/plausible` and assert the expected service mode.
        6. Tmpfiles leave state-directory permissions to each service's `StateDirectory` handling.
    5. Keycloak delegates component configuration to reusable service modules.
        1. `keycloak-compose.nix` combines Keycloak and PostgreSQL in one NixOS container.
        2. It passes the Keycloak unix socket to `proxy-compose` as the default origin.
        3. The [Keycloak service module](../HANDOVER.md) creates the socket bridge inside the container.
        4. `modules.keycloak`, `modules.postgresql`, and `modules.proxy-compose` provide customization.
    6. n8n remains unfinished under **G6**.
        1. `n8n-compose.nix` declares an OCI image, `.n8n` and `.n8n-files` state directories, and port mappings.
        2. State directories use mode `0700` and UID/GID 1000.
        3. Readiness probes target `/healthz/readiness`.
        4. It reads undeclared `cfg.n8n.serviceName` and incorrectly reads `cfg.proxy-compose.hostname`.
        5. Its Cloudflared lookup also keys proxy-compose by container name rather than instance name.
        6. Do not enable n8n without repairing those evaluation paths.
        7. The centralized image scope already provides `n8n_v2 = 2.28.7`.
    7. Hermes composes multiple backends but still has skeleton gaps.
        1. `hermes-agent-compose.nix` exposes pass-throughs for netns, sleep-on-idle, Squid, Fastcrw, LiteLLM, Camofox, SearXNG, and Hermes.
        2. Namespace and sleep-on-idle identifiers default to the instance name.
        3. Hermes and LiteLLM share a NixOS container with separate state paths and sockets.
        4. Camofox runs as an OCI container and Fastcrw is optional.
        5. The wrapper provisions identity, tmpfiles, sops environment files, namespaces, cgroups, bind mounts, and proxy settings.
        6. Secret keys default to `<name>/hermes-agent-envFile` and `<name>/litellm-envFile`.
        7. Hermes receives a default LiteLLM base URL ending in `/v1`, telemetry policy, `CAMOFOX_URL`, and optional `FIRECRAWL_API_URL`.
        8. Sleep-on-idle endpoints map `default` to Hermes and `litellm` to LiteLLM.
        9. Host wiring reads identity, state, and endpoint fields back from the inner service options.
        10. `containerName`, `serviceName`, and `shared-run-dir` remain referenced without declared compose options.
        11. SearXNG creation remains commented out while optional consumers expect unsupported `.url` and `.serviceName` fields.
    8. Frappe is the largest OCI stack in the repository.
        1. Its [dedicated handover](frappe-v16-compose/HANDOVER.md) covers bench capture, unix sockets, deployment safety, and storage.
    9. Container boundaries require explicit persistence and naming.
        1. NixOS containers use `container@<name>.service`, while OCI unit names come from their declared `serviceName`.
        2. Copy the existing runtime-specific unit mapping when extending namespace or cgroup targets.
        3. Self-referential reads of inner container config require the referenced inner options to exist.
        4. Ephemeral roots lose unbound data on restart.
        5. Set `nixpkgs.pkgs = pkgs` inside NixOS containers to share the intended package set.
        6. Review secret-directory mounts because a parent directory may expose more secrets than the requested file.
        7. Configure the Podman backend locally for new OCI modules.
    10. Extend applications from active examples rather than dormant templates.
        1. Use Plausible for NixOS packages or Frappe for upstream OCI images.
        2. Add state directories, sops paths, publication, readiness, namespace, and cgroup wiring together.
        3. The [services handover](../HANDOVER.md) describes the shared primitives.
        4. The [sleep-on-idle handover](../sleep-on-idle/HANDOVER.md) describes activation and freezing.
        5. The [root handover](../../../HANDOVER.md) records **G1** and **G6**.
        6. The [image-scope handover](../../../myPkgs/HANDOVER.md) describes centralized image tags.
