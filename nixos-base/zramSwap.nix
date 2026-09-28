{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.myOpt;
in {
  zramSwap.enable = true;
  zramSwap.memoryPercent = 400;
  swapDevices = mkForce [];
  zramSwap.writebackDevice = null;
}
