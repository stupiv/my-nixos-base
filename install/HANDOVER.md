- This is the handover for `install/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62`, and it was not build-tested because the authoring sandbox had no `nix`.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It is the **machine-preparation layer** covering partitioning, firmware/hardware enumeration, and a set of deliberate tripwires that force a human to finish the install by hand.
    - It is imported by the *consumer's* host configuration, since neither `flake.nixosModules.laptop-base` nor `vps-base` pulls it in and nothing inside this repo references it.
    - `install/default.nix` is the whole entry point and reads `imports = [ ./disko-config.nix ./hardware-configuration.nix ./nixos-hardware.nix ./reminders.nix ./stateVersion.nix ];`.
    - Note the commented-out `# ./defaut.nix` (sic) on the first line, which is the repo-wide convention of leaving a self-import marker in every import list, so keep it.

  - Files
    - `default.nix` imports the five files below and does not fail on purpose.
    - `disko-config.nix` declares `myOpt.disk.{id,device}` and builds the GPT/btrfs layout, and does not fail on purpose.
    - `hardware-configuration.nix` sets `hardware.facter.reportPath = ./facter.json` and **does** fail on purpose if `facter.json` is absent.
    - `nixos-hardware.nix` is a bare `throw` plus a commented skeleton and **always** fails on purpose.
    - `reminders.nix` is a `throw` about the sops age key and **always** fails on purpose.
    - `stateVersion.nix` is an empty attrset containing `# system.stateVersion = "26.05";`, so it does not fail but leaves the value unset.

  - `disko-config.nix` in detail
    - Both options are `types.singleLineStr` with no defaults, so the host must set them.
      - `myOpt.disk.id` is the attribute name of the disk in `disko.devices.disk`.
      - `myOpt.disk.device` is the block device, for example `/dev/nvme0n1`.
    - The layout is a GPT table on `disk.<id>` with three partitions:
      - `boot` is 1M of type `EF02` and exists for BIOS boot / grub MBR.
      - `ESP` is 500M of type `EF00`, formatted vfat and mounted at `/boot` with `umask=0077, noatime`.
      - `root` takes the remaining 100 % as btrfs.
        - Subvolume `@root` mounts at `/` with `compress=zstd, lazytime`.
        - Subvolume `@nix` mounts at `/nix` with `compress=zstd, noatime`.
    - The module also sets `boot.loader.efi.canTouchEfiVariables = false` and `boot.loader.grub.efiInstallAsRemovable = true`.
    - Those match `nixos-base/bootloader.nix`, which uses `device = "nodev"`, `efiSupport = true` and the same removable-EFI defaults.
    - This trio is what makes an "install onto a USB stick / no NVRAM writes" workflow possible **and** means GRUB is not registered in the firmware boot order.

  - The three tripwires (do not "fix" them)
    - `reminders.nix` throws `"Have you forgotten to prepare age key at /var/lib/sops-nix/key.txt?"`.
      - It corresponds to `nixos-base/sops.nix`, which sets `sops.age.keyFile = "/var/lib/sops-nix/key.txt"`.
      - Delete the file from the import list once the key is provisioned on the machine.
    - `nixos-hardware.nix` throws `"Have you forgotten to import nixos-hardware modules?"` and is followed by a commented skeleton referencing `inputs.nixos-hardware.nixosModules.<…>`.
      - The file also hints at the DMI lookup that picks the module, namely `cat /sys/class/dmi/id/product_version` and `cat /sys/class/dmi/id/product_name`.
      - The `nixos-hardware` flake input exists but is referenced by *no* module, so this is its only intended consumer.
    - `hardware-configuration.nix` throws with `builtins.pathExists` guidance telling you to run `nixos-anywhere --generate-hardware-config nixos-facter ./facter.json`.
      - `facter.json` is **not** committed, is the only untracked-worthy artefact in the repo, and must be generated per machine.

  - Gotchas
    - `stateVersion.nix` is an **empty module**, so `system.stateVersion` stays unset and NixOS warns or errs.
      - The commented value is `"26.05"`, matching the `nixpkgs-2605` channel that `flake.nix` pins.
      - When you uncomment it, `git commit` the change per host and never bump it later, because `stateVersion` is a behaviour latch rather than a version.
    - `myOpt.disk.id` becomes an *attribute name*, so it must be a valid Nix identifier-ish string such as `main` rather than `main disk`.
    - The `boot` partition is `EF02` and only 1 MiB because it exists purely for BIOS/legacy GRUB.
      - On a pure-UEFI machine it is harmless dead weight, and deleting it requires editing the GPT layout, which disko only does destructively.
    - Both `disko` (`fileSystems`) and `hardware.facter` will fight any hand-written `hardware-configuration.nix` from `nixos-generate-config`, because this repo replaces that file entirely with the facter variant.

  - How to add a machine
    - Add the generated `./facter.json`.
    - Set `myOpt.disk.id`, `myOpt.disk.device` and `system.stateVersion` in the host config, plus everything in the root handover's mandatory-values list.
    - Uncomment and fill `nixos-hardware.nix` with the right `inputs.nixos-hardware.nixosModules.<model>`.
    - Remove `./reminders.nix` from the import list **after** the age key is in place.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers deployment and **G2**, the fact that `install/` is orphaned.
    - [`../nixos-base/HANDOVER.md`](../nixos-base/HANDOVER.md) covers `bootloader.nix` and `sops.nix`.
