{
  inputs = {
    nixpkgs.follows = "nixpkgs-2605";
    nixpkgs-2605.url = "github:nixos/nixpkgs/7dcdd87373d72e7a2173e4db02e20d3d7f495cfd"; # See https://channels.nixos.org/nixos-26.05/git-revision

    nixpkgs-2611.url = "github:nixos/nixpkgs/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504"; # See https://channels.nixos.org/nixos-unstable/git-revision
    hermes-agent.url = "github:NousResearch/hermes-agent/v0.21.7"; # No inputs follows for cache to work
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };

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
    flake.nixosModules.laptop-base = ./laptop-base;
    flake.nixosModules.vps-base = ./vps-base;
  });
}
