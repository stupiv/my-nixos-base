{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (myLibFinal: myLibPrev: {
        replaceModules = nixpkgs-x: modules:
          [
            {
              disabledModules = modules;
            }
          ]
          ++ map (m: "${nixpkgs-x}/nixos/modules/${m}") modules;
      });
    })
  ];
}
