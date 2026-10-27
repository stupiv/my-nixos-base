{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = final.myLib.extend (ml-final: ml-prev:
        with prev.lib; {
          unbracketIpv6 = s: let
            p = ml-final.splitLastColon s;
          in
            if p.port != null && hasPrefix "[" p.host && hasSuffix "]" p.host
            then "${substring 1 (stringLength p.host - 2) p.host}:${p.port}"
            else s;
        });
    })
  ];
}
