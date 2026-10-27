{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = final.myLib.extend (ml-final: ml-prev:
        with prev.lib; {
          splitLastColon = s: let
            m = builtins.match "^(.*):([^:]*)$" s;
          in
            if m == null
            then {
              host = s;
              port = null;
            }
            else {
              host = elemAt m 0;
              port = elemAt m 1;
            };
        });
    })
  ];
}
