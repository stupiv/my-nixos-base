{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (myLibFinal: myLibPrev: let
        wpFetch = type: {
          name,
          version,
          hash,
        }: (prev.stdenv.mkDerivation {
          inherit name version hash;
          src = prev.fetchzip {
            inherit name version hash;
            url = "https://downloads.wordpress.org/${type}/${name}.${version}.zip";
          };
          installPhase = "mkdir -p $out; cp -R * $out/";
        });
      in {
        wpPluginFetch = wpFetch "plugin";
        wpThemeFetch = wpFetch "theme";
      });
    })
  ];
}
