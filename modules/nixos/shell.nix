{ pkgs, ... }:
{
  programs.zsh = {
    enable                    = true;
    autosuggestions.enable    = true;
    syntaxHighlighting.enable = true;
    histSize   = 10000;
    setOptions = [
      "HIST_IGNORE_DUPS"   # don't record duplicate commands back-to-back
      "HIST_IGNORE_SPACE"  # commands prefixed with a space are not saved
      "SHARE_HISTORY"      # all open terminals share the same history
      "AUTO_CD"            # type a dir name alone to cd into it
    ];
    interactiveShellInit = ''
      # fzf: Ctrl-R = fuzzy history, Ctrl-T = fuzzy file, Alt-C = fuzzy cd
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      # zoxide: smarter cd — use  z <partial-name>  to jump to frequent dirs
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
    '';
  };

  # starship prompt — works in any terminal, no nerd fonts needed.
  # Config lives in the repo at config/starship.toml, symlinked live-editable to
  # ~/.config/starship.toml by modules/home/starship.nix. This module only enables
  # the package + shell init; it deliberately sets no `settings`, because the NixOS
  # starship module only forces STARSHIP_CONFIG to its own generated file when
  # ~/.config/starship.toml is absent — and we want that user file to win so it can
  # be edited live and themed by noctalia.
  programs.starship.enable = true;
}
