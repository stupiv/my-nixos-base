1. `sleep-on-idle/` provides socket-activated applications with idle cgroup freezing.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../HANDOVER.md).
    2. Seven Nix files separate the mechanism's concerns.
        1. `default.nix` imports the implementation files and retains the self-import comment marker.
        2. `options.nix` declares `myOpt.sleep-on-idle.<name>`.
        3. `socket.nix` creates endpoint socket units wanted by `sockets.target`.
        4. `proxy.nix` creates endpoint proxy services and health-check scripts.
        5. `slice.nix` creates each instance's cgroup slice.
        6. `freeze.nix` defines the freeze and thaw service template.
        7. `set-cgroup-parent.nix` places selected workloads into the slice.
    3. Instances describe endpoints, readiness, and workload membership.
        1. `enable` defaults to `true` and `sliceName` defaults to the instance name.
        2. `endpoints.<endpoint>.origin` describes the application endpoint in unbracketed form.
        3. Proxy endpoints default to `/run/sleep-on-idle/<slice>/<endpoint>.sock`.
        4. Read-only proxy names follow `sleep-on-idle-proxy@<slice>-<endpoint>`.
        5. `exit-idle-time` defaults to 300 seconds and `TimeoutStartSec` defaults to 30 seconds.
        6. Health-check options select an endpoint, path, and retry sleep interval defaulting to `1`.
        7. `set-cgroup-parent` selects systemd services, OCI containers, and NixOS containers.
        8. `freezeName` and `freezeUnit` are read-only derived values.
        9. [`mkEndpointOpt`](../../../myLib/HANDOVER.md) brackets proxy listeners and curl targets while leaving origins unbracketed.
    4. A client connection activates the proxy and wakes the application.
        1. Endpoint sockets set `TriggerLimitBurst = 0` and `NoDelay = true`.
        2. Proxy services require and follow their socket and freeze unit.
        3. Starting the freeze unit runs `systemctl thaw %i.slice`.
        4. `ExecStartPre` waits for the readiness probe before forwarding traffic.
        5. `ExecStart` runs `systemd-socket-proxyd --exit-idle-time=<seconds> <origin.ip-socket>`.
        6. Idle proxy exit releases the freeze unit and triggers `systemctl freeze %i.slice`.
    5. Freeze-unit lifecycle semantics are intentionally inverted.
        1. `RemainAfterExit = true` keeps the thaw unit active after its start command completes.
        2. `StopWhenUnneeded = true` freezes the slice when no proxy needs the unit.
        3. Both systemctl commands use a leading `-` so redundant state changes do not fail the unit.
        4. Workload units receive forced `wantedBy = [freezeUnit]` and `StopWhenUnneeded = false`.
        5. OCI containers also receive `--cgroup-parent=<slice>` to prevent Podman escaping the slice.
        6. Disabling socket trigger limits avoids burst-related refusal.
    6. Health checks select transport-specific probes.
        1. Scripts are generated at build time with `writeShellScriptBin`.
        2. PHP-FPM socket paths containing `phpfpm` use `cgi-fcgi -bind -connect`.
        3. Other unix sockets use `curl --unix-socket`.
        4. TCP endpoints use ordinary curl with bracketed IPv6 URLs.
        5. A missing health-check socket triggers an assertion.
        6. The default health-check endpoint derives from `endpoints.default.origin`.
    7. Consumers depend on the default endpoint contract.
        1. `proxy-compose.nix` creates an instance for each published application.
        2. Squid groups its service and proxy units into a slice.
        3. Compose modules use the mechanism for Plausible, Keycloak, Frappe, Hermes, n8n, and parked Chatwoot.
        4. Frappe reads `endpoints.default.proxy.name` when assigning proxy units to its namespace.
        5. Defining only differently named endpoints breaks consumers expecting `endpoints.default`.
    8. Namespace and freeze boundaries require deliberate review.
        1. Probes run in the proxy unit's namespace, which remains the host namespace unless explicitly reassigned.
        2. Namespace-local loopback requires matching proxy placement or an accessible unix-socket bridge.
        3. Freezing pauses open sockets and database connections without closing them.
        4. Do not add databases or non-idempotent workloads to a shared freeze slice blindly.
        5. Freeze units run root systemctl without additional sandboxing.
        6. Empty slice declarations acquire cgroups when workloads join them.
    9. Extend the mechanism through existing endpoint and membership options.
        1. Add endpoints or instances while preserving default-endpoint contracts.
        2. Follow `plausible-compose.nix` for a complete integration example.
        3. Prefer cheap, idempotent readiness probes such as Frappe's `/api/method/ping`.
    10. Read the related handovers before changing shared contracts.
        1. The [services handover](../HANDOVER.md) describes proxies, Squid, and publication.
        2. The [library handover](../../../myLib/HANDOVER.md) describes endpoint normalization.
        3. The [compose handover](../compose/HANDOVER.md) describes major consumers.
