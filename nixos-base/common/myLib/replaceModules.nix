{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (ml-final: ml-prev: {
        replaceModules = nixpkgs-x: modules: (
          [
            {
              disabledModules = modules;
            }
          ]
          ++ map (m: "${nixpkgs-x}/nixos/modules/${m}") modules
        );
      });
    })
  ];
}
