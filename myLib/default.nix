{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.lib.makeScope prev.newScope (self: {
        replaceModules = import ./replaceModules.nix {};
      });
    })
  ];
}
