{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    tealdeer
    lf
  ];
}
