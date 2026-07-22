{lib, ...}:
with lib; {
  boot.loader.efi.canTouchEfiVariables = mkDefault false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = mkDefault true;
  };
}
