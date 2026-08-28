{
  config,
  lib,
  inputs,
  ...
}:
with lib; {
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    backupFileExtension = "backup";
    users.${config.myOpt.admin.username} = {
      imports = [
        ./home-manager
      ];
      home = {
        inherit (config.myOpt.admin) username homeDirectory;
        stateVersion = mkDefault (versions.majorMinor version);
      };
    };
  };
}
