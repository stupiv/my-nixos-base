- This is the handover for `nixos-base/services/compose/unmaintained/wordpress/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It is a **native-NixOS** WordPress deployment with no OCI image, running `services.wordpress` inside a nspawn container served over a **phpfpm unix socket**, with plugins and themes fetched from wordpress.org and pinned by hash.
    - It is dormant, because the parent directory is commented out of `../../default.nix` and there is no `default.nix` here either.

  - Files
    - `wordpress-compose.nix` is 361 lines and is the whole module, declaring two `myLib` helpers **as options** plus `myOpt.wordpress-compose`.
    - `wp-plugins.nix` is an **overlay** adding `pkgs.myPkgs.<plugin>_v<version>` entries built with `wpPluginFetch`.
    - `wpFetch.nix` is an **overlay** adding `pkgs.myLib.wpPluginFetch` and `wpThemeFetch`, which are the fetchers themselves.
    - Two coexisting ways to get the fetchers are the main source of confusion here:
      - `wordpress-compose.nix` declares `options.myLib.wpFetch`, `options.myLib.wpPluginFetch` and `options.myLib.wpThemeFetch` as `readOnly = true` with `types.functionTo …` and gives them defaults built with `pkgs.stdenv.mkDerivation`.
      - `wpFetch.nix` defines the *same names* as an `overrideScope` on `pkgs.myLib`.
    - You cannot use both.
    - `wp-plugins.nix` uses `final.myLib.wpPluginFetch`, which is the **overlay** version, and never mentions the option-declared one.
    - If you revive this, pick the overlay path and delete the option declarations from `wordpress-compose.nix`.

  - How the fetchers work
    - The core fetcher is `wpFetch = type: { name, version, hash }: stdenv.mkDerivation { … };`.
    - Its source is `src = fetchzip { url = "https://downloads.wordpress.org/${type}/${name}.${version}.zip"; … };`.
    - Its install phase is `installPhase = "mkdir -p $out; cp -R * $out/";`.
    - The plugin variant is `wpPluginFetch = wpFetch "plugin";`, where `type` is `"plugin"` or `"theme"`.
    - `type` is exactly the URL path shape used by wordpress.org.
    - Because it is a `fetchzip` with a `hash`, every plugin is reproducible, **but the hash must be supplied manually**, so updating a plugin means fetching the new hash with `nix-prefetch-url --unpack <url>`.
    - `wp-plugins.nix` pins a curated set with `_v<major>` suffixes, each with a comment linking to its wordpress.org page, including `opcache-manager_v3`, `apcu-manager_v4`, `cache-enabler_v1`, `two-factor_v0_16` and `safe-svg`.
    - That naming of `<slug>_v<major>` is the repo-wide convention for pinned third-party artefacts and is mirrored in `myPkgs/oci-img.nix`.

  - The module's interesting options
    - `container.name` and `container.origin.ip-socket` exist because the phpfpm pool socket is derived from the **hostname** as `services.phpfpm.pools."wordpress-${hostname}".socket`, so two WordPress instances on one host cannot collide.
    - The top-level `origin.ip-socket` is the host-side path `/run/<container>${container.origin.ip-socket}`, meaning the socket is **path-prefixed** rather than moved, and the container binds the whole `/run/<container>` dir.
    - `plausible-domain` injects an `mu-plugin` named `plausible.php` that prints a `<script defer data-domain=…>` tag, giving analytics without a plugin.
    - `muPlugins`, `themes` and `plugins` are `attrsOf path` whose values are store paths typically from `wpPluginFetch`.
    - `wordpress.{uploadsDir,fontsDir}` are per-hostname subdirs under `stateDir`, so a shared state dir can host several sites.
    - `symlinks`, `settings`, `extraConfig` and `extra-installPhase` are pass-through into `services.wordpress`.
    - `serviceName` defaults to `"container@${container.name}"` and is `readOnly`, which is the nspawn convention matching `plausible-compose.nix`.

  - Gotchas
    - **`origin.ip-socket` is prefixed, not overridden**, so the host path is `/run/<container.name>` plus the in-container path, and changing `container.name` changes the host socket path and breaks any Caddy config keyed on the old path.
    - **`plausible-domain` depends on Plausible being deployed**, because the generated mu-plugin hard-codes `https://${plausible-domain}/js/script.js` and there is no check that the domain resolves.
    - **PHP-FPM socket health checks** are special-cased in `sleep-on-idle/proxy.nix`, which uses `cgi-fcgi -bind -connect` instead of `curl` for paths containing `phpfpm`, and that branch exists *because of* modules like this one.
      - The string match is `hasInfix "phpfpm" health-check.ip-socket`, so a socket path that does not contain `phpfpm` will be probed with `curl --unix-socket` and fail.
    - **Two `myLib` definitions of the same functions** exist as described above, so resolve them before re-enabling or you will get "attribute already defined" behaviour that depends on which is evaluated first.
    - **No `default.nix`** exists in this directory, so even if `unmaintained` were un-commented in `../../default.nix` this subdirectory would still not be imported.
      - Reviving it needs a new `imports = [ ./wordpress/wordpress-compose.nix ./wordpress/wp-plugins.nix ./wordpress/wpFetch.nix ]` somewhere, and the overlays must be imported *before* anything that reads `pkgs.myPkgs.<plugin>`.
    - Plugin and theme store paths are pointers into the Nix store, so a `wordpress` state dir that has already copied plugin files will **not** pick up a new version until WordPress re-syncs, which is exactly why `symlinks` exists.

  - How to revive it
    - Import `wpFetch.nix` as an overlay into an imported module, and then `wp-plugins.nix`.
    - Delete the duplicate `options.myLib.wp*` declarations from `wordpress-compose.nix`.
    - Add the module to `../../default.nix`, or better to `compose/` directly rather than `unmaintained/`.
    - Provide `wordpress.package`, `wordpress.stateDir`, `wordpress.themes` which is required with no default, `mariadb.package`, `proxy-compose`, and a `container.origin.ip-socket` that the phpfpm pool actually binds.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers `compose-template.nix` and `chatwoot-compose.nix`.
    - [`../../../sleep-on-idle/HANDOVER.md`](../../../sleep-on-idle/HANDOVER.md) explains that the `phpfpm` → `cgi-fcgi` health-check branch exists because of socket setups like this one.
    - [`../../../../../myLib/HANDOVER.md`](../../../../../myLib/HANDOVER.md) covers the scope these overlays extend.
