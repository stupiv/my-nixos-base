{pkgs, ...}: {
  environment.systemPackages = with pkgs; [btop];
  environment.shellAliases = {
    "htop" = "btop";
    "top" = "btop";
  };
}
