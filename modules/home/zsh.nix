{ repoDir, ... }:
{
  programs.zsh = {
    enable    = true;   # tells home-manager to create and manage ~/.zshrc
    # Completion is set up once, by /etc/zshrc (modules/nixos/shell.nix), which
    # already puts every profile's completions on $fpath. Home-manager's copy
    # only ran compinit a second time: ~50 ms of the ~150 ms every new shell
    # and tmux pane took to start. It has to be this copy that goes: zoxide's
    # init in /etc/zshrc registers `z` completion only if compinit ran before it.
    enableCompletion = false;
    # keep the bulk of interactive config in an editable repo file; the guard
    # avoids a broken shell if the repo isn't present at repoDir
    initContent = ''
      [ -f ${repoDir}/config/zsh/rc.zsh ] && source ${repoDir}/config/zsh/rc.zsh
    '';
  };
}
