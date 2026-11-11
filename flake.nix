{
  inputs = {
    nixpkgs.follows = "nixpkgs-2605";
    nixpkgs-2605.url = "github:nixos/nixpkgs/7dcdd87373d72e7a2173e4db02e20d3d7f495cfd"; # See https://channels.nixos.org/nixos-26.05/git-revision
    nixpkgs-2611.url = "github:nixos/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6"; # See https://channels.nixos.org/nixos-unstable/git-revision
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v0.22.7"; # See https://github.com/NousResearch/hermes-agent/tags
      # inputs.nixpkgs.follows = "nixpkgs"; # No inputs.nixpkgs.follows for hermes-agent.cachix.org to work
      # inputs.flake-parts.follows = "flake-parts";
    };
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
    oisd = {
      url = "github:sjhgvr/oisd";
      flake = false;
    };
    camoufox-nix = {
      url = "github:maximoffua/camoufox-nix";
      inputs.nixpkgs.follows = "nixpkgs-2611";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
  outputs = inputs: (inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    systems = ["x86_64-linux" "aarch64-linux"];
    flake.nixosModules.laptop-base = ./laptop-base;
    flake.nixosModules.vps-base = ./vps-base;
  });
}
