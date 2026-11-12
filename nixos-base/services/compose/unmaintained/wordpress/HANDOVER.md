1. `compose/unmaintained/wordpress/` preserves a native NixOS WordPress deployment and fetcher overlays.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../../../HANDOVER.md).
    2. The stack runs WordPress inside a NixOS container through a PHP-FPM unix socket.
        1. Its parent is excluded from active imports and this directory has no `default.nix`.
        2. Plugins and themes use hash-pinned WordPress downloads rather than OCI images.
    3. Three files implement composition and fetching.
        1. `wordpress-compose.nix` declares `myOpt.wordpress-compose` and option-based WordPress fetchers.
        2. `wpFetch.nix` adds overlapping fetcher functions to `pkgs.myLib` through an overlay.
        3. `wp-plugins.nix` uses the overlay fetchers to add versioned plugin packages to `pkgs.myPkgs`.
        4. The option-based and package-scope fetcher interfaces are separate implementations that should be consolidated before revival.
        5. Prefer the overlay interface already used by `wp-plugins.nix` and remove redundant option declarations.
    4. Fetchers construct reproducible plugin and theme store paths.
        1. `wpFetch` accepts a type and `{ name, version, hash }`.
        2. It fetches `https://downloads.wordpress.org/<type>/<name>.<version>.zip` with `fetchzip`.
        3. The install phase copies extracted content into the derivation output.
        4. `wpPluginFetch` and `wpThemeFetch` specialize the type to `plugin` and `theme`.
        5. Update hashes with `nix-prefetch-url --unpack <url>` when bumping versions.
        6. Curated plugins include `opcache-manager_v3`, `apcu-manager_v4`, `cache-enabler_v1`, `two-factor_v0_16`, and `safe-svg`.
        7. Versioned attribute names follow the same broad convention as centralized OCI image attributes.
    5. Runtime options connect container sockets and site state.
        1. PHP-FPM pool names derive from the hostname as `wordpress-<hostname>`.
        2. `container.origin.ip-socket` selects the in-container socket.
        3. Host `origin.ip-socket` prefixes that path with `/run/<container.name>`.
        4. The container bind-mounts the corresponding run directory.
        5. Read-only `serviceName` defaults to `container@<container.name>`.
        6. `muPlugins`, `themes`, and `plugins` accept attribute sets of store paths.
        7. Upload and font directories are hostname-specific subdirectories of WordPress state.
        8. `symlinks`, `settings`, `extraConfig`, and `extra-installPhase` pass through to `services.wordpress`.
        9. `plausible-domain` generates a must-use plugin loading `https://<domain>/js/script.js`.
    6. Socket naming and state synchronization affect correctness.
        1. Renaming the container changes the host socket path and requires matching proxy changes.
        2. Plausible analytics assumes an existing reachable deployment without validating it.
        3. Sleep-on-idle uses FastCGI health checks only when the socket path contains `phpfpm`.
        4. Other unix-socket paths receive curl probes and may fail against PHP-FPM.
        5. Existing copied plugin files may require synchronization or symlink handling to adopt new store versions.
    7. Revival requires explicit imports and complete options.
        1. Import the fetcher overlay and plugin overlay before consuming their package attributes.
        2. Remove duplicate option-based fetchers from `wordpress-compose.nix`.
        3. Import the WordPress module explicitly or move it into the active compose directory.
        4. Supply WordPress package, state, required themes, MariaDB package, proxy settings, and the actual PHP-FPM socket.
        5. Uncommenting the parent directory alone does not import this entry-point-free subtree.
    8. Read the related handovers before revival.
        1. The [parent handover](../HANDOVER.md) describes Chatwoot and the outdated compose template.
        2. The [sleep-on-idle handover](../../../sleep-on-idle/HANDOVER.md) describes FastCGI health checks.
        3. The [library handover](../../../../../myLib/HANDOVER.md) describes the scope extended by fetcher overlays.
