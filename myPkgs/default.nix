{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.lib.makeScope prev.newScope (self: {
        frappe.tags = prev.callPackages ./frappe-tags.nix {};
        oci-img = prev.callPackages ./oci-img.nix {};
        plausible_v3 = final.pkgs-2511.plausible;
        clickhouse_v26_3 = final.pkgs-2605.clickhouse-lts;
      });
    })
  ];
}
