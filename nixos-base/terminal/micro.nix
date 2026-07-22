{
  lib,
  pkgs,
  ...
}:
with lib; {
  environment.systemPackages = with pkgs; [micro wl-clipboard];
  environment.sessionVariables.EDITOR = getExe pkgs.micro;

  programs.nano.enable = false;
}
