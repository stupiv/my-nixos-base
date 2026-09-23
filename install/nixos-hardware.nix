throw "Have you forgotten to import nixos-hardware modules?"
# cat /sys/class/dmi/id/product_version
# cat /sys/class/dmi/id/product_name
# {
#   config,
#   lib,
#   pkgs,
#   inputs,
#   ...
# }:
# with lib; let
# in {
#   imports = [
#     inputs.nixos-hardware.nixosModules.
#   ];
# }

