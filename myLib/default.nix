{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.lib.makeScope prev.newScope (self: {
        mkEndpointOpt = (import ./mkEndpointOpt.nix {}) {inherit (prev) lib;};
        replaceModules = import ./replaceModules.nix {};
      });
    })
  ];
}
