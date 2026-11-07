# HANDOVER — `nixos-base/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix` in the
> authoring sandbox).

## What this directory is for

The **shared system layer**: identity, SSH, DNS, bootloader, Nix settings, swap policy, locale, and (via subdirectories)
every service, the terminal environment, and the unmaintained leftovers. Both flake outputs import it:

```nix
# nixos-base/default.nix (imports, abridged)
imports = [
  ../myLib  ../myPkgs
  ./dnscrypt  ./services  ./terminal
  ./admin.nix ./bootloader.nix ./caddy.nix ./dirs.nix ./firmware.nix ./ipv6.nix
  ./networkmanager.nix ./nix.nix ./nix-ld.nix ./no-coredump.nix ./openssh.nix
  ./podman.nix ./shellcheck.nix ./sops.nix ./specialisation.nix ./time.nix
  ./tlp.nix ./vmVariant.nix ./zramSwap.nix
];
```

That list **is** the table of contents. `./unmaintained` is *not* imported (there is no `unmaintained/default.nix`).

## Files at this level

| File | Effect | Options declared |
| --- | --- | --- |
| `admin.nix` | creates the admin user, group, `wheel`, and (conditionally) SSH access | `myOpt.admin.{username,hashedPassword,authorizedKeys,homeDirectory(ro),uid,gid}` |
| `openssh.nix` | sshd hardening + optional Cloudflared ingress for SSH | `myOpt.openssh.{enable,port,cloudflared.tunnel-id,cloudflared.hostname}` |
| `bootloader.nix` | GRUB/EFI, `device = "nodev"`, removable-EFI defaults | – |
| `caddy.nix` | adds `nss`/`nss.tools` to `caddy.service` PATH (for `getent`/name lookups) — only when Caddy is enabled | – |
| `dirs.nix` | `myOpt.homeDir`, `myOpt.downloadDir` | yes |
| `networkmanager.nix` | enables NM, puts the admin in `networkmanager` | – |
| `nix.nix` | flakes/`nix-command`, `trusted-users = [admin]`, `cache.nixos.org` + `nix-community.cachix.org` | – |
| `nix-ld.nix` | `programs.nix-ld.enable = true` (run non-Nix binaries, needed by AppImages/VS Code-style tools) | – |
| `no-coredump.nix` | disables systemd-coredump and sets `kernel.core_pattern = "|/bin/false"` | – |
| `podman.nix` | `virtualisation.podman.autoPrune.enable = true` (backend itself is set per-service) | – |
| `shellcheck.nix` | `systemd.enableStrictShellChecks = true` — **all** `ExecStart`/script strings must be clean | – |
| `sops.nix` | imports `inputs.sops-nix.nixosModules.sops`, `sops.age.keyFile = /var/lib/sops-nix/key.txt` | – |
| `specialisation.nix` | turns `myOpt.specialisation.<name>` into `specialisation.<name>` and sets `myOpt.specialisation.<name>.inside = true` inside it | yes |
| `time.nix` | `time.timeZone = "Asia/Ho_Chi_Minh"`, `LC_TIME = en_DK.UTF-8` | – |
| `tlp.nix` | TLP settings + conflict assertions | – |
| `zramSwap.nix` | zram at 400 %, `swapDevices = mkForce []`, `writebackDevice = null` | – |
| `vmVariant.nix` | `virtualisation.vmVariant{WithBootLoader}` = 8 GiB / 4 cores | – |
| `ipv6.nix` | static v6 address + default gateway (active only when `public-address != null`) | `myOpt.ipv6.{public-address,interface,gateway}` |
| `firmware.nix` | `hardware.enableRedistributableFirmware = true` | – |

Subdirectories: [`dnscrypt/`](dnscrypt/HANDOVER.md), [`services/`](services/HANDOVER.md),
[`terminal/`](terminal/HANDOVER.md), [`unmaintained/`](unmaintained/HANDOVER.md).

## The identity → privilege chain (read this before touching `admin.nix`)

```
myOpt.admin.authorizedKeys != null
   └─> myOpt.openssh.enable  (mkDefault)
         ├─> services.openssh.enable = true, ports = [ myOpt.openssh.port ]
         ├─> services.openssh.settings.AllowUsers = [ myOpt.admin.username ]
         └─> myOpt.cloudflared.<tunnel-id>.ingress.<hostname> = "ssh://localhost:<port>"
               (only when myOpt.openssh.cloudflared.tunnel-id != null)
```

Independently of that, `admin.nix` always creates `users.users.<username>` with `isNormalUser`, `wheel`,
`uid = 1000` (default), `gid` following `uid`, and `users.groups.<username>`.

`openssh.nix` also unconditionally sets `startWhenNeeded = true`, `PermitRootLogin = "no"`,
`PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`. So password login is **off**, and the only
way in is a key in `authorizedKeys` (directly or via the tunnel).

**Trap:** `myOpt.openssh.ports = [cfg.port]` with `port` defaulting to `null` (**G5**). Set the port whenever you set
`enable = true`, otherwise the unit gets a literal `null`.

## Cross-cutting contracts

1. **`myOpt` is shared, so `dirs.nix`/`ipv6.nix`/`admin.nix` all write into the same namespace.** `dirs.nix` declares
   `myOpt` at the top level (not `myOpt.dirs`) — that is intentional, and it is why `myOpt.homeDir`/`myOpt.downloadDir`
   read naturally. Do not add a second `options.myOpt = …` declaration that redefines those keys.
2. **Anything that needs the admin user must be defined after/alongside `admin.nix`** in the same evaluation, since
   `networkmanager.nix`, `dirs.nix` and `services/rclone-automount.nix` reference `config.myOpt.admin.username` /
   `homeDirectory` without a `mkIf`. They therefore *require* the option to be set (no default) even if the feature is
   otherwise unused.
3. **`systemd.enableStrictShellChecks = true`** is global. New `ExecStart` lines with unquoted variables or `[` without
   quoting will fail the build, not just warn. This is also why `services/sleep-on-idle/proxy.nix` builds health-check
   scripts with `writeShellScriptBin` instead of inlining them.
4. **`no-coredump`** also removes the ability to debug crashes. There is no opt-out module; override
   `systemd.coredump.enable` + `boot.kernel.sysctl."kernel.core_pattern"` with `mkForce` if you need core dumps.
5. **`zramSwap`** forces `swapDevices = []`. On a RAM-constrained machine that is the difference between OOM-kill and
   thrash — deliberate, per the author.
6. **`specialisation.nix`** is the only place that uses `mkForce` on a `myOpt` value: inside a specialisation,
   `myOpt.specialisation.<name>.inside` becomes `true` so that modules can branch on "am I the variant?".
7. **`tlp.nix`** asserts it is not combined with `power-profiles-daemon`, `thermald` or `powertop`, and force-disables
   all three when TLP is on. `laptop-base/tlp.nix` enables TLP, so those three are effectively banned on the laptop.

## Known issues local to this directory

- **G5** `ports = [cfg.port]` with `null` default (above).
- **G7** `USB_EXLUDE_PHONE` in `tlp.nix` looks like a typo for `USB_EXCLUDE_PHONE` (**⚠ verify** against
  linrunner.de); `TLP_AUTO_SWITCH = 0` + `TLP_PROFILE_DEFAULT = "SAV"` also pin the power profile.
- **G8** hard-coded `Asia/Ho_Chi_Minh` + `en_DK.UTF-8` for `LC_TIME`. Deliberate (metric clock in English), but it is
  the first thing to override on a machine in another region.
- `caddy.nix` uses `mkIf config.services.caddy.enable` — if you replace Caddy with something else, this module becomes
  a no-op rather than an error, which is intended.
- `vmVariant.nix` writes `virtualisation = rec { vmVariant = { virtualisation = { … }; }; vmVariantWithBootLoader = vmVariant; }`
  — note the *inner* `virtualisation` attribute; that is the shape `nixos-rebuild build-vm` expects, not a typo.
- `firmware.nix` unconditionally enables redistributable firmware; that pulls unfree-ish blobs and is not wanted on a VPS
  image. Override to `false` if you care about image size.

## How to add a module here

- Cross-cutting, tiny, and unconditional → a file at this level + one line in `default.nix`.
- Workload → `services/` (see its handover for the `myOpt.<svc>` instance pattern).
- Anything that might break a build → `unmaintained/`, which is not imported.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — mandatory values, global issue list, layer diagram
- [`services/HANDOVER.md`](services/HANDOVER.md) — the biggest surface area in the repo
- [`../install/HANDOVER.md`](../install/HANDOVER.md) — hardware/disko side, sops key provisioning
