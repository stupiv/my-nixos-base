nixpkgs-x: modules: (
  [
    {
      disabledModules = modules;
    }
  ]
  ++ map (m: "${nixpkgs-x}/nixos/modules/${m}") modules
)
