# HANDOVER — `laptop-base/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix` in the
> authoring sandbox).

## What this directory is for

The **workstation flavour** of the flake, exported as `flake.nixosModules.laptop-base`. It is `nixos-base` plus a
desktop environment, laptop hardware toggles, and a home-manager profile. Everything here is a thin, mostly
`mkDefault`-ed overlay on top of the shared layer — the difference between the laptop and the VPS is *only* this
directory plus `install/`.

```nix
# laptop-base/default.nix
imports = [
  ../nixos-base  ./common
  # ./home-manager            ← the *directory* is imported via ./home-manager.nix
  ./appimage.nix ./bluetooth.nix ./cosmic.nix ./de.nix ./firewall.nix ./home-manager.nix
  ./ipv6.nix ./naturalScrolling.nix ./nixos_ozone_wl.nix ./plasma6.nix ./sound.nix
  ./tlp.nix ./tmpfs.nix ./vi-ime.nix
];
```

## Files at this level

| File | Effect | Notes |
| --- | --- | --- |
| `de.nix` | `myOpt.cosmic.enable = true` | **the desktop choice lives here** — one line, override it to switch DE |
| `cosmic.nix` | COSMIC DE + greeter when `myOpt.cosmic.enable` | excludes `cosmic-edit/player/screenshot/term` (they use their own equivalents), sets `COSMIC_DATA_CONTROL_ENABLED = 1` |
| `plasma6.nix` | KDE Plasma 6 + SDDM (Wayland) when `myOpt.plasma6.enable` | default `false`; **no assertion prevents enabling both DEs** |
| `home-manager.nix` | wires `inputs.home-manager.nixosModules.default` for `myOpt.admin.username`, imports `./home-manager` | see below |
| `appimage.nix` | `programs.appimage.{enable,binfmt}` | requires `nix-ld` (already on in `nixos-base`) for extracted AppImages to run |
| `bluetooth.nix` | `hardware.bluetooth.enable` | requires the `bluetooth` service + firmware from `nixos-base/firmware.nix` |
| `firewall.nix` | `services.caddy.openFirewall = false` | laptop publishes nothing publicly; tunnels/unix sockets only |
| `ipv6.nix` | `myOpt.ipv6.public-address = null` | satisfies the **mandatory** option from `nixos-base/ipv6.nix` — without this the module would not evaluate |
| `tmpfs.nix` | `boot.tmp.useTmpfs = true` | `/tmp` in RAM; large builds/dotnet-style temp files eat RAM |
| `tlp.nix` | `services.tlp.enable = true` | triggers `nixos-base/tlp.nix`: thresholds 75/80 %, and **force-disables** `power-profiles-daemon`, `thermald`, `powertop` |
| `naturalScrolling.nix` | `services.libinput.touchpad.naturalScrolling` | global, no per-device granularity |
| `sound.nix` | PipeWire + Pulse + `dconf` | `dconf` is there specifically so home-manager's `services.easyeffects` can work |
| `nixos_ozone_wl.nix` | `NIXOS_OZONE_WL = 1` | makes Electron/Chromium apps use Wayland |
| `vi-ime.nix` | fcitx5 + `fcitx5-bamboo`, Wayland frontend | Vietnamese input (Telex/VNI); needs `i18n.inputMethod.enable` → set via `mkDefault true` |
| `unmaintained/` | see [`unmaintained/HANDOVER.md`](unmaintained/HANDOVER.md) | not imported |

Subdirectories: [`common/`](common/HANDOVER.md), [`home-manager/`](home-manager/HANDOVER.md),
[`unmaintained/`](unmaintained/HANDOVER.md).

## The home-manager wiring (the part that confuses people)

```nix
home-manager = {
  extraSpecialArgs = { inherit inputs; };
  backupFileExtension = "backup";
  users.${config.myOpt.admin.username} = {
    imports = [ ./home-manager ];
    home = { inherit (config.myOpt.admin) username homeDirectory;
             stateVersion = config.system.nixos.release; };
  };
};
```

- Only **one** user is managed, and its name comes from `myOpt.admin.username` — so `admin.nix` must be configured
  before any of this evaluates.
- `home.stateVersion` is derived from the **system** release, so it tracks the nixpkgs pin (`26.05`). That is convenient
  but means bumping nixpkgs silently bumps the home-manager state version, which is normally a latch you set once.
- `backupFileExtension = "backup"` is why you will find `*.backup` files next to managed dotfiles after a switch.
- `extraSpecialArgs = { inherit inputs; }` is what lets `home-manager/zen-browser.nix` and `flatpak.nix` import flake
  inputs (`inputs.zen-browser-flake…`, `inputs.nix-flatpak…`).
- The commented `# ./home-manager` in `default.nix` is *not* a mistake: importing the directory as a **NixOS** module
  would be wrong, since it contains home-manager modules. It is imported from inside `home-manager.users.<user>.imports`.

## Gotchas

- **Two DEs are possible at once.** `de.nix` hard-sets `myOpt.cosmic.enable = true`; if a host also sets
  `myOpt.plasma6.enable = true` you get COSMIC + Plasma + both greeters, with no assertion to stop you. Changing the
  desktop means editing/overriding `de.nix`, not just flipping a flag.
- **`plasma6.nix` and `cosmic.nix` both declare `services.displayManager` bits** (`sddm` vs `cosmic-greeter`); they are
  not coordinated and will conflict at the greeter level.
- **`ipv6.nix` is load-bearing, not cosmetic** — it exists to satisfy a mandatory option of `nixos-base/ipv6.nix`.
  Deleting it breaks evaluation of the whole laptop module.
- **No hardware config here.** No `hardware-configuration`, no `boot.loader.*` device, no `networking.hostName`, no
  `system.stateVersion`. Those come from the consumer (`install/` + host config). `nixos-base/bootloader.nix` uses
  `device = "nodev"`/removable EFI, which pairs with `install/disko-config.nix`.
- **`tmpfs` + `zramSwap` + `swapDevices = []`** together mean this machine has no durable swap and a RAM-backed `/tmp`.
  On a 16 GB laptop with 400 % zram, suspend/hibernate behaviour is worth re-checking after any change here.
- **`sound.nix` sets `programs.dconf.enable`** only because easyeffects (home-manager, gated on
  `myOpt.easyeffects.enable`, default false) needs it. If you enable easyeffects, remember the dconf requirement is
  already satisfied.
- **`vi-ime.nix` uses `mkDefault true` for `i18n.inputMethod.enable`** — a host can turn the IME off without a conflict,
  but `type = "fcitx5"` is a plain value, so switching to ibus requires `mkForce`.
- `nixos_ozone_wl.nix` and `appimage.nix` are the two "modern desktop plumbing" files; both are safe on a VPS but
  pointless there, which is why they are not in `nixos-base`.

## How to change the desktop

1. Set `myOpt.plasma6.enable = true` and `myOpt.cosmic.enable = false` (override `de.nix`), **or** edit `de.nix`.
2. Make sure only one `services.displayManager` provider is enabled.
3. Check `NIXOS_OZONE_WL` still applies; `vi-ime` uses the Wayland frontend so it requires a Wayland session.
4. Prefer adding packages to [`home-manager/packages.nix`](home-manager/packages.nix) over
   `environment.systemPackages` — the laptop keeps user tooling in home-manager.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — mandatory values, global issues (**G4**: `pkgs.pkgs-2611` is undefined and
  `home-manager/activitywatch.nix` is imported unconditionally)
- [`../nixos-base/HANDOVER.md`](../nixos-base/HANDOVER.md) — everything shared, incl. `tlp.nix` assertions
- [`home-manager/HANDOVER.md`](home-manager/HANDOVER.md) — the user profile
- [`../install/HANDOVER.md`](../install/HANDOVER.md) — disko + facter + sops key
