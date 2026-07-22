{
  config,
  lib,
  ...
}:
with lib; {
  systemd.coredump.enable = false;
  boot.kernel.sysctl."kernel.core_pattern" = mkIf (!config.systemd.coredump.enable) "|/bin/false";
}
