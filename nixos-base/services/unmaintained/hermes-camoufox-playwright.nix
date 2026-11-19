{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  ps = config.services.hermes-agent.package.python.pkgs;
  old-playwright = ps.callPackage "${inputs.camoufox-nix}/packages/python-camoufox/playwright.nix" {};
  new-playwright = old-playwright.overrideAttrs (old: {
    passthru =
      (old.passthru or {})
      // {
        requiredPythonModules = remove ps.typing-extensions old-playwright.requiredPythonModules;
      };
  });

  browser = inputs.camoufox-nix.packages.${pkgs.stdenv.hostPlatform.system}.camoufox-bin;
in {
  services.hermes-agent = {
    extraPythonPackages = [new-playwright];
    environment = {
      CAMOUFOX_EXECUTABLE = getExe browser;
      CAMOUFOX_EXECUTABLE_PATH = getExe browser;
    };
    settings.terminal.env_passthrough = [
      "CAMOUFOX_EXECUTABLE"
      "CAMOUFOX_EXECUTABLE_PATH"
    ];
  };
}
