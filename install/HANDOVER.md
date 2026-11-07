# HANDOVER — `install/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested (no `nix` in the
> authoring sandbox).

## What this directory is for

The **machine-preparation layer**: partitioning, firmware/hardware enumeration, and a set of deliberate tripwires that
force a human to finish the install by hand. It is imported by the *consumer's* host configuration — neither
`flake.nixosModules.laptop-base` nor `vps-base` pulls it in, and nothing inside this repo references it.

```nix
# install/default.nix — the whole file
{ imports = [ ./disko-config.nix ./hardware-configuration.nix ./nixos-hardware.nix
              ./reminders.nix ./stateVersion.nix ]; }
```

Note the commented-out `# ./defaut.nix` (sic) on the first line: the repo-wide convention of leaving a self-import
marker in every import list. Keep it.

## Files

| File | What it does | Fails on purpose? |
| --- | --- | --- |
| `default.nix` | imports the five files below | no |
| `disko-config.nix` | declares `myOpt.disk.{id,device}` and builds the GPT/btrfs layout | no |
| `hardware-configuration.nix` | `hardware.facter.reportPath = ./facter.json` | **yes**, if `facter.json` is absent |
| `nixos-hardware.nix` | bare `throw` + a commented skeleton | **yes**, always |
| `reminders.nix` | `throw` about the sops age key | **yes**, always |
| `stateVersion.nix` | empty attrset with `# system.stateVersion = "26.05";` | no (but leaves it unset) |

## `disko-config.nix` in detail

Options (both `types.singleLineStr`, no defaults — the host must set them):

- `myOpt.disk.id` — attribute name of the disk in `disko.devices.disk`
- `myOpt.disk.device` — e.g. `/dev/nvme0n1`

Layout:

```
disk.<id> (gpt)
├── boot   1M    EF02        (BIOS boot / grub MBR)
├── ESP    500M  EF00        → vfat → /boot   (umask=0077, noatime)
└── root   100%  btrfs
    ├── @root → /      (compress=zstd, lazytime)
    └── @nix  → /nix   (compress=zstd, noatime)
```

The module also sets `boot.loader.efi.canTouchEfiVariables = false` and
`boot.loader.grub.efiInstallAsRemovable = true` — matching `nixos-base/bootloader.nix`, which uses `device = "nodev"`,
`efiSupport = true`, and the same removable-EFI defaults. This trio is what makes an "install onto a USB stick / no
NVRAM writes" workflow possible **and** means GRUB is not registered in the firmware boot order.

## The three tripwires (do not "fix" them)

1. **`reminders.nix`** — `throw "Have you forgotten to prepare age key at /var/lib/sops-nix/key.txt?"`.
   Corresponds to `nixos-base/sops.nix` (`sops.age.keyFile = "/var/lib/sops-nix/key.txt"`). Delete the file from the
   import list once the key is provisioned on the machine.
2. **`nixos-hardware.nix`** — `throw "Have you forgotten to import nixos-hardware modules?"`, followed by a commented
   skeleton (`inputs.nixos-hardware.nixosModules.<…>`). The file also hints at the DMI lookup that picks the module:
   `cat /sys/class/dmi/id/product_version`, `cat /sys/class/dmi/id/product_name`.
   The `nixos-hardware` flake input exists but is referenced by *no* module — this is the only intended consumer.
3. **`hardware-configuration.nix`** — throws through `builtins.pathExists` guidance: run
   `nixos-anywhere --generate-hardware-config nixos-facter ./facter.json`. `facter.json` is **not** committed (the only
   untracked-worthy artefact in the repo) and must be generated per machine.

## Gotchas

- `stateVersion.nix` is an **empty module**. `system.stateVersion` stays unset, and NixOS warns/errs. The commented
  value is `"26.05"`, i.e. the `nixpkgs-2605` channel that `flake.nix` pins. When you uncomment it, `git commit` the
  change per host, never bump it later — `stateVersion` is a behaviour latch, not a version.
- `myOpt.disk.id` becomes an *attribute name*, so it must be a valid Nix identifier-ish string (`main`, not `main disk`).
- The `boot` partition is `EF02` and only 1 MiB: it exists purely for BIOS/legacy GRUB. On a pure-UEFI machine it is
  harmless dead weight; deleting it requires editing the GPT layout, which disko only does destructively.
- Both `disko` (`fileSystems`) and `hardware.facter` will fight any hand-written `hardware-configuration.nix` from
  `nixos-generate-config` — this repo replaces that file entirely with the facter variant.

## How to add a machine

1. Add `./facter.json` (generated).
2. Set in the host config: `myOpt.disk.id`, `myOpt.disk.device`, `system.stateVersion`, plus everything in the root
   handover's "mandatory values" table.
3. Uncomment / fill `nixos-hardware.nix` with the right `inputs.nixos-hardware.nixosModules.<model>`.
4. Remove `./reminders.nix` from the import list **after** the age key is in place.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) §6 (deployment), §7 (**G2**: `install/` is orphaned)
- [`../nixos-base/HANDOVER.md`](../nixos-base/HANDOVER.md) — `bootloader.nix`, `sops.nix`
