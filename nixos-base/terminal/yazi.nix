{pkgs, ...}: {
  environment.systemPackages = with pkgs; [yazi];
  environment.shellAliases = {
    "lf" = "yazi";
  };
}
