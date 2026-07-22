{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.myPkgs.overrideScope (myPkgsFinal: myPkgsPrev: {
        plausible_v3 = final.pkgs-2511.plausible;
      });
    })
  ];
}
