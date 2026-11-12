{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    tealdeer
    yazi
    ripgrep
    btop
  ];
}
