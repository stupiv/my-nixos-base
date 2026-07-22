{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.lib.makeScope prev.newScope (self: {});
      myPkgs = prev.lib.makeScope prev.newScope (self: {});
    })
  ];
}
