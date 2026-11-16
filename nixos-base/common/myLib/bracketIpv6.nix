{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (ml-final: ml-prev:
        with prev.lib; {
          bracketIpv6 = original: let
            socket = ml-final.splitLastColon original;
          in
            # if hasInfix ":" socket.host && !(hasPrefix "[" socket.host) && !(hasSuffix "]" socket.host)
            # then
            #   (
            #     if socket.port == null
            #     then "[${socket.host}]"
            #     else "[${socket.host}]:${socket.port}"
            #   )
            # else original;
            if socket.port == null
            then original
            else if hasPrefix "[" socket.host && hasSuffix "]" socket.host
            then original
            else if hasInfix ":" socket.host
            then "[${socket.host}]:${socket.port}"
            else original;
        });
    })
  ];
}
