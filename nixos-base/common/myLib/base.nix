{lib, ...}: {
  nixpkgs.overlays = lib.mkBefore [
    (final: prev: {
      myLib = prev.lib.makeScope prev.newScope (self: {});
    })
  ];
}
