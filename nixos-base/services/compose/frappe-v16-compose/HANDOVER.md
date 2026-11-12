1. `frappe-v16-compose/` runs a complete Frappe and ERPNext v16 bench through Podman.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../../HANDOVER.md).
        1. The authoring sandbox lacked both Nix and Podman.
    2. The bench and runtime use separate storage mechanisms.
        1. A host `<name>-build.service` builds the bench with the official `frappe/build` image.
        2. `frappe-bench-store.sh` captures the result with `nix store add-path` and protects it with a gcroot symlink.
        3. That gcroot provides the stable bench mount source for runtime containers.
        4. Containers mount the bench with `:O` while sites and logs use persistent bind mounts.
        5. MariaDB, both Valkey instances, and Gunicorn communicate through unix sockets.
        6. Only frontend nginx listens on `127.0.0.1:8080` inside the workload namespace.
        7. Caddy or Cloudflared reaches the application through proxy-compose and sleep-on-idle.
    3. Files separate options, orchestration, and lifecycle scripts.
        1. `default.nix` imports `options.nix` and `frappe-compose.nix`.
        2. `options.nix` declares the large option tree without implementation configuration.
        3. `frappe-compose.nix` creates containers, units, directories, namespaces, and proxy wiring.
        4. `frappe-bench-store.sh` builds, captures, gcroots, and hashes the bench specification.
        5. `bench-init.sh` initializes apps, strips Git metadata and logs, and seeds empty common-site configuration.
        6. `bench-readonly.sh` checks for an existing bench without rebuilding it.
        7. `configurator.sh` writes database sockets, Valkey sockets, Socket.IO settings, maintenance flags, and hostname configuration.
        8. `create-site.sh` waits for prerequisites, creates a site, and writes `.site-created`.
        9. `migrate.sh` waits for the marker, installs missing apps, and migrates the site.
        10. The [unmaintained handover](unmaintained/HANDOVER.md) describes the previous implementation.
    4. Each `myOpt.frappe-v16-compose.<name>` instance exposes deployment options.
        1. `enable` defaults to `true`.
        2. `proxy-compose-id` and `netns-id` default to the instance name.
        3. Read-only `sleep-on-idle-id` derives from proxy-compose.
        4. `sopsFile` defaults to the instance name.
        5. `frappe.readOnlyMode` defaults to `false`.
        6. Frappe storage options include `stateDir`, `sitesPath`, `logsPath`, `benchDir`, and `siteName`.
        7. `frappe.apps.<app>` selects enabled repositories and branches.
        8. `frappe.base.tag` selects `docker.io/frappe/base:<tag>`.
        9. `frappe.build.tag` defaults to the ERPNext branch.
        10. MariaDB options select its image, state directory, and environment-secret key.
        11. Valkey options select images, persistent state, container names, and cache or queue socket folders.
        12. `modules.proxy-compose` and `modules.squid` pass host configuration through.
        13. The Frappe env file must provide `INIT_ADMIN_PASSWORD` and `DB_PASSWORD` under `<name>/frappe_envfile`.
        14. The MariaDB env file must provide `MARIADB_ROOT_PASSWORD` under `<name>/mariadb_envfile`.
    5. Assertions and dependencies enforce deployment ordering.
        1. An enabled ERPNext declaration requires its branch to match `frappe.build.tag`.
        2. Declaring Helpdesk requires Telephony.
        3. The build unit must complete before the configurator starts.
        4. MariaDB and Valkey precede configurator, create-site, migrate, backend workers, and frontend in dependency order.
        5. Runtime components include backend, websocket, scheduler, two queue workers, and frontend.
    6. Read-only mode is the deployment-safety mechanism.
        1. First deployment requires `readOnlyMode = false` to build, create, install, and migrate.
        2. Read-only mode uses `bench-readonly.sh` and fails if no bench exists.
        3. It sets `READONLY=1` so create-site refuses new site creation.
        4. It skips app synchronization and migration.
        5. It enables `maintenance_mode` and `allow_reads_during_maintenance`.
        6. Set read-only mode after successful deployment to prevent unintended bench and site changes.
        7. Temporarily disable it for deliberate upgrades and restore it afterward.
    7. Tmpfiles ownership is part of the runtime contract.
        1. Frappe sites and logs use mode `0770` with ownership `1000:0`.
        2. The backend socket directory uses mode `0750` with ownership `1000:0`.
        3. MariaDB state uses mode `0700` with ownership `999:999`.
        4. MariaDB socket directories use mode `0750` with ownership `999:0`.
        5. Valkey state and socket directories use mode `0750` with ownership `999:0`.
        6. Valkey queue state uses mode `0700` with ownership `999:0` and recursive ownership correction.
        7. Incorrect ownership prevents database startup or socket creation.
    8. Store capture and mounts impose operational constraints.
        1. Store insertion and gcroot creation require root or an appropriately trusted Nix user.
        2. The rebuild key hashes the apps specification, branch, and builder tag into a 12-character prefix stored beside the gcroot.
        3. `FORCE=1` bypasses the unchanged-specification skip.
        4. Environment and resource-limit changes do not automatically rebuild the bench.
        5. The configurator regenerates `sites/apps.txt` from installed app directories.
        6. Assets mount read-only and noexec under `sites/assets`, so preserve mount ordering relative to the bench overlay.
        7. Keep host socket paths, container socket paths, and socket environment variables synchronized.
        8. MariaDB uses `--skip-networking` and `--socket`, while Valkey instances use `--port 0` and unix sockets.
        9. The cache Valkey disables snapshots, while the queue Valkey keeps persistent state.
        10. `MARIADB_SERVICE = "localhost"` satisfies application configuration without enabling database TCP.
        11. Frontend health checks use `/api/method/ping` on namespace-local `127.0.0.1:8080`.
        12. Namespace wiring requires a sleep-on-idle instance with `endpoints.default`.
        13. Containers default to `autoStart = false`.
        14. Hostname changes require rerunning the configurator because `HOST_NAME` embeds `https://<hostname>`.
    9. Upgrade the stack deliberately.
        1. Select compatible base-image tags, builder tags, and app branches while satisfying the ERPNext assertion.
        2. Update MariaDB and Valkey images from the [central image definitions](../../../../myPkgs/oci-img.nix).
        3. Disable read-only mode and watch build, configurator, create-site, and migrate complete.
        4. Re-enable read-only mode after verification.
        5. Read create-site's recovery guidance before touching partial-site markers or using destructive `bench drop-site` commands.
    10. Read the related handovers for shared infrastructure.
        1. The [compose handover](../HANDOVER.md) compares container runtimes and persistence.
        2. The [sleep-on-idle handover](../../sleep-on-idle/HANDOVER.md) describes the freeze and thaw front door.
        3. The [services handover](../../HANDOVER.md) describes namespaces and Squid egress.
        4. The [previous-generation handover](unmaintained/HANDOVER.md) explains historical design differences.
