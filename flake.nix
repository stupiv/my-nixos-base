{
  inputs = {
    nixpkgs.follows = "nixpkgs-2605";
    nixpkgs-2605.url = "github:nixos/nixpkgs/7dcdd87373d72e7a2173e4db02e20d3d7f495cfd"; # See https://channels.nixos.org/nixos-26.05/git-revision
    nixpkgs-2611.url = "github:nixos/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6"; # See https://channels.nixos.org/nixos-unstable/git-revision
    # nixpkgs-2611.follows = "hermes-agent/nixpkgs";
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v0.23.1"; # See https://github.com/NousResearch/hermes-agent/tags
      # inputs.nixpkgs.follows = "nixpkgs"; # No inputs.nixpkgs.follows for hermes-agent.cachix.org to work # No rebuild when update nixpkgs. Rebuiild only we update hermes-agent.
      # inputs.flake-parts.follows = "flake-parts";
    };
    lightpanda = {
      url = "github:lightpanda-io/browser/1.0.3";
      # inputs.nixpkgs.follows = "nixpkgs"; # No rebuild when update nixpkgs. Rebuiild only we update lightpanda.
    }; # tmp
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };
    home-manager-2611 = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-2611";
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
      url = "github:nix-community/disko/?ref=latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
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
    hermes-official-plugins = {
      url = "github:NousResearch/hermes-official-plugins";
      flake = false;
    };
  };
  outputs = inputs: (inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    systems = ["x86_64-linux" "aarch64-linux"];
    flake.nixosModules.laptop-base = ./laptop-base;
    flake.nixosModules.vps-base = ./vps-base;
  });
}
