{pkgs, ...}: {
  users.defaultUserShell = pkgs.fish;
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      bind [3\;5~ kill-word
      bind \cH backward-kill-word
      set fish_greeting (date)
    '';
  };
}
