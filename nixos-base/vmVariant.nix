{lib, ...}:
with lib; {
  virtualisation = rec {
    vmVariant = {
      virtualisation = {
        memorySize = mkDefault (8 * 1024);
        cores = mkDefault 4;
      };
    };
    vmVariantWithBootLoader = vmVariant;
  };
}
