{config, ...}: let
  inherit (config.myOpt) User;
in {
  networking.networkmanager.enable = true;
  users.users.${User}.extraGroups = ["networkmanager"];
}
