{
  config,
  lib,
  inputs,
  ...
}:
with lib; {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  options.myOpt.disk = {
    id = mkOption {
      type = types.singleLineStr;
    };
    device = mkOption {
      type = types.singleLineStr;
    };
  };

  config = {
    disko.devices.disk.${config.myOpt.disk.id} = {
      inherit (config.myOpt.disk) device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
          };
          ESP = {
            type = "EF00";
            size = "500M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077" "noatime"];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "lazytime"];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = ["compress=zstd" "noatime"];
                };
              };
            };
          };
        };
      };
    };
  };
}
