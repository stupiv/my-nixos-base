# HANDOVER — `nixos-base/services/compose/unmaintained/wordpress/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

A **native-NixOS** WordPress deployment (no OCI image): `services.wordpress` inside a nspawn container, served over a
**phpfpm unix socket**, with plugins/themes fetched from wordpress.org and pinned by hash. Dormant — the parent
directory is commented out of `../../default.nix`, and there is no `default.nix` here either.

## Files

| File | Role |
| --- | --- |
| `wordpress-compose.nix` | 361 lines: the whole module. Declares two `myLib` helpers **as options** and `myOpt.wordpress-compose` |
| `wp-plugins.nix` | an **overlay** adding `pkgs.myPkgs.<plugin>_v<version>` entries built with `wpPluginFetch` |
| `wpFetch.nix` | an **overlay** adding `pkgs.myLib.wpPluginFetch` / `wpThemeFetch` — the fetchers themselves |

Two coexisting ways to get the fetchers, which is the main source of confusion here:

- `wordpress-compose.nix` declares `options.myLib.wpFetch`, `options.myLib.wpPluginFetch`, `options.myLib.wpThemeFetch`
  (`readOnly = true`, `types.functionTo …`) and gives them defaults built with `pkgs.stdenv.mkDerivation`;
- `wpFetch.nix` defines the *same names* as an `overrideScope` on `pkgs.myLib`.

You cannot use both. `wp-plugins.nix` uses `final.myLib.wpPluginFetch`, i.e. the **overlay** version, and
`wp-plugins.nix` never mentions the option-declared one. If you revive this, pick the overlay path and delete the
option declarations from `wordpress-compose.nix`.

## How the fetchers work

```nix
wpFetch = type: { name, version, hash }: stdenv.mkDerivation {
  src = fetchzip { url = "https://downloads.wordpress.org/${type}/${name}.${version}.zip"; … };
  installPhase = "mkdir -p $out; cp -R * $out/";
};
wpPluginFetch = wpFetch "plugin";   # type = plugin | theme
```

`type` is `"plugin"` or `"theme"`, which is exactly the URL path shape used by wordpress.org. Because it is a
`fetchzip` with a `hash`, every plugin is reproducible — **but the hash must be supplied manually**, and updating a
plugin means fetching the new hash (`nix-prefetch-url --unpack <url>`).

`wp-plugins.nix` pins a curated set with `_v<major>` suffixes, each with a comment linking to its wordpress.org page:
`opcache-manager_v3`, `apcu-manager_v4`, `cache-enabler_v1`, `two-factor_v0_16`, `safe-svg`, … This naming
(`<slug>_v<major>`) is the repo-wide convention for pinned third-party artefacts (mirrored in `myPkgs/oci-img.nix`).

## The module's interesting options

| Option | Why it exists |
| --- | --- |
| `container.name`, `container.origin.ip-socket` | the phpfpm pool socket is derived from the **hostname**: `services.phpfpm.pools."wordpress-${hostname}".socket`, so two WordPress instances on one host cannot collide |
| `origin.ip-socket` (top level) | host-side path `/run/<container>${container.origin.ip-socket}` — i.e. the socket is **path-prefixed**, not moved. The container binds the whole `/run/<container>` dir |
| `plausible-domain` | injects an `mu-plugin` (`plausible.php`) that prints a `<script defer data-domain=…>` tag — analytics without a plugin |
| `muPlugins` / `themes` / `plugins` | `attrsOf path`, values are store paths (typically from `wpPluginFetch`) |
| `wordpress.{uploadsDir,fontsDir}` | per-hostname subdirs under `stateDir`, so a shared state dir can host several sites |
| `symlinks`, `settings`, `extraConfig`, `extra-installPhase` | pass-through into `services.wordpress` |

`serviceName` defaults to `"container@${container.name}"` and is `readOnly` — the nspawn convention, matching
`plausible-compose.nix`.

## Gotchas

- **`origin.ip-socket` is prefixed, not overridden**: host path is `/run/<container.name>` + in-container path. If you
  change `container.name`, the host socket path changes too and any Caddy config keyed on the old path breaks.
- **`plausible-domain` depends on Plausible being deployed** — the generated mu-plugin hard-codes
  `https://${plausible-domain}/js/script.js`. There is no check that the domain resolves.
- **PHP-FPM socket health checks**: `sleep-on-idle/proxy.nix` special-cases paths containing `phpfpm` and uses
  `cgi-fcgi -bind -connect` instead of `curl` — that branch exists *because of* modules like this one. The string match
  is `hasInfix "phpfpm" health-check.ip-socket`, so a socket path that does not contain `phpfpm` will be probed with
  `curl --unix-socket` and fail.
- **Two `myLib` definitions of the same functions** (see above) — resolve before re-enabling, or you will get
  "attribute already defined" behaviour that depends on which is evaluated first.
- **No `default.nix`** in this directory: even if `unmaintained` were un-commented in `../../default.nix`, this
  subdirectory would still not be imported. Reviving it needs a new `imports = [ ./wordpress/wordpress-compose.nix
  ./wordpress/wp-plugins.nix ./wordpress/wpFetch.nix ]` somewhere (and the overlays must be imported *before* anything
  that reads `pkgs.myPkgs.<plugin>`).
- Plugin/theme store paths are pointers into the Nix store, so a `wordpress` state dir that has already copied plugin
  files will **not** pick up a new version until WordPress re-syncs; `symlinks` exists for exactly that reason.

## How to revive it

1. Import `wpFetch.nix` (overlay) into an imported module; then `wp-plugins.nix`.
2. Delete the duplicate `options.myLib.wp*` declarations from `wordpress-compose.nix`.
3. Add the module to `../../default.nix` (or better: to `compose/` directly, not `unmaintained/`).
4. Provide `wordpress.package`, `wordpress.stateDir`, `wordpress.themes` (required, no default), `mariadb.package`,
   `proxy-compose`, and a `container.origin.ip-socket` that the phpfpm pool actually binds.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — `compose-template.nix`, `chatwoot-compose.nix`
- [`../../../sleep-on-idle/HANDOVER.md`](../../../sleep-on-idle/HANDOVER.md) — the `phpfpm` → `cgi-fcgi` health-check
  branch exists because of socket setups like this one
- [`../../../../../myLib/HANDOVER.md`](../../../../../myLib/HANDOVER.md) — the scope these overlays extend
