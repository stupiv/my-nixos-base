{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  myOpt.cosmic.enable = true;
}
