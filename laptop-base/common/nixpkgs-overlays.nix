{
  nix.settings = {
    substituters = ["https://hermes-agent.cachix.org"];
    trusted-public-keys = ["hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="];
  };
  nixpkgs.overlays = [
    (final: prev: {
      # lib = prev.lib.extend (lfinal: lprev: {
      #   inherit (final.pkgs-2611.lib) customisation;
      # });
    })
  ];
}
