{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.myPkgs.overrideScope (myPkgsFinal: myPkgsPrev: {
        clickhouse_v26_3 = final.pkgs-2605.clickhouse-lts;
      });
    })
  ];
}
