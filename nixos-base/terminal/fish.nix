{pkgs, ...}: {
  users.defaultUserShell = pkgs.fish;
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting (uuidgen -r && date)

      function stamp_start --on-event fish_preexec
        set -g __cmd_started (date '+%T')
      end
      function stamp_end --on-event fish_postexec
        printf '[%s → %s] took %ss\n' $__cmd_started (date '+%T') (math --scale=2 "$CMD_DURATION / 1000")
      end
    '';
  };
}
