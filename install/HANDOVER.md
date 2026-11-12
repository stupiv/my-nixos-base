1. `install/` prepares individual machines and must be imported by the downstream host.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../HANDOVER.md).
    2. `default.nix` imports five preparation modules.
        1. Keep the commented `# ./defaut.nix` self-import marker.
        2. `disko-config.nix` defines partitioning and requires `myOpt.disk.id` and `myOpt.disk.device`.
        3. `hardware-configuration.nix` requires a generated `facter.json` report.
        4. `nixos-hardware.nix` deliberately throws until hardware modules are selected.
        5. `reminders.nix` deliberately throws until the sops age key is provisioned.
        6. `stateVersion.nix` leaves `system.stateVersion` commented out.
    3. Disk options are required single-line strings.
        1. `myOpt.disk.id` selects the `disko.devices.disk` attribute.
        2. `myOpt.disk.device` selects a block device such as `/dev/nvme0n1`.
    4. The GPT layout supports BIOS and removable EFI boot.
        1. The BIOS boot partition uses 1 MiB and type `EF02`.
        2. The 500 MiB `EF00` ESP mounts at `/boot` as vfat with `umask=0077,noatime`.
        3. Remaining space becomes btrfs with an `@root` subvolume mounted at `/` using `compress=zstd,lazytime`.
        4. The `@nix` subvolume mounts at `/nix` using `compress=zstd,noatime`.
        5. EFI variable writes are disabled and GRUB installs as removable media without firmware registration.
        6. Shared bootloader configuration uses `device = "nodev"` and `efiSupport = true`.
    5. Complete the installation tripwires per machine.
        1. Generate `facter.json` with `nixos-anywhere --generate-hardware-config nixos-facter ./facter.json`.
        2. Treat `facter.json` as machine-specific generated data rather than a shared hardware report.
        3. Select hardware modules through `inputs.nixos-hardware.nixosModules.<model>`.
        4. Inspect `/sys/class/dmi/id/product_version` and `/sys/class/dmi/id/product_name` to identify hardware.
        5. Provision `/var/lib/sops-nix/key.txt` before removing `./reminders.nix` from the import list.
        6. Set `system.stateVersion` explicitly and retain that initial value across upgrades.
        7. The commented state-version example is `26.05`.
        8. Supply disk options and the root handover's mandatory host values before deployment.
    6. Review destructive changes and conflicting hardware declarations carefully.
        1. Removing the legacy BIOS partition changes the disko layout destructively.
        2. Avoid combining this facter-based hardware module with conflicting `nixos-generate-config` filesystem declarations.
        3. Neither exported flake module imports this installation layer automatically.
    7. Read the related handovers before provisioning.
        1. The [root handover](../HANDOVER.md) covers deployment and **G2**.
        2. The [shared-system handover](../nixos-base/HANDOVER.md) covers GRUB and sops.
