{
  inputs = {
    nixpkgs.follows = "nixpkgs-2511";
    nixpkgs-2511.url = "github:nixos/nixpkgs/e820eb4a444b46a19b2e03e8dfd2359439ff30fe"; # See https://channels.nixos.org/nixos-25.11
    nixpkgs-2605.url = "github:nixos/nixpkgs/6d663c0533ff269008fb84e45930151e37c99db9"; # See https://channels.nixos.org/nixos-26.05
    nixpkgs-2611.url = "github:nixos/nixpkgs/419fe0f449b3fbe3bdd53d9840288db4509ec32e"; # See https://channels.nixos.org/nixpkgs-unstable

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    functional_blocklist = {
      url = "https://big.oisd.nl/domainswild2";
      flake = false;
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser-flake = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs: (inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    systems = ["x86_64-linux" "aarch64-linux"];
    flake.nixosModules.laptop-base = ../laptop-base;
    flake.nixosModules.vps-base = ../vps-base;
  });
}
