{pkgs, ...}: {
  environment.systemPackages = with pkgs; [bat];
  environment.shellAliases."cat" = "bat -p";
}
