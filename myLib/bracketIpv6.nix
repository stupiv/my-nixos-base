{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = final.myLib.extend (ml-final: ml-prev:
        with prev.lib; {
          bracketIpv6 = s: let
            p = ml-final.splitLastColon s;
          in
            if p.port == null
            then s
            else if hasPrefix "[" p.host && hasSuffix "]" p.host
            then s
            else if hasInfix ":" p.host
            then "[${p.host}]:${p.port}"
            else s;
        });
    })
  ];
}
