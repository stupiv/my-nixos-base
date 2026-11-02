{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.lib.makeScope prev.newScope (self: {
        oci-img = prev.callPackages ./oci-img.nix {};
      });
    })
  ];
}
