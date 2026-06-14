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

  # starship prompt — works in any terminal, no nerd fonts needed
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[❯](green)";
        error_symbol   = "[❯](red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo  = true;
      };
      git_status.disabled = false;
    };
  };
}
