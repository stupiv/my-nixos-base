{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (config.myOpt.trash-empty) age frequency;
in {
  options.myOpt.trash-empty = {
    frequency = mkOption {
      type = types.singleLineStr;
      default = "*-01,03,05,07,09,11-02";
    };
    age = mkOption {
      default = "56";
      type = types.singleLineStr;
    };
  };

  config = {
    environment.systemPackages = with pkgs; [trash-cli];

    systemd.services.trash-empty = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.trash-cli}/bin/trash-empty -f --all-users ${age}";
      };
    };
    systemd.timers.trash-empty = {
      timerConfig = {
        OnCalendar = frequency;
        Persistent = true;
        Unit = "trash-empty.service";
      };
      wantedBy = ["timers.target"];
    };
  };
}
