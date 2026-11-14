{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (ml-final: ml-prev: {
        countTrue = list: builtins.length (builtins.filter (x: x) list);
      });
    })
  ];
}
