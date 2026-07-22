{pkgs, ...}: {
  environment.systemPackages = with pkgs; [eza];
  environment.shellAliases = {
    "ls" = "eza -a --group-directories-first";
    "ll" = "eza -al --group-directories-first";
    "lt" = "eza -aT --group-directories-first";
  };
}
