{ repoDir, ... }:
{
  programs.zsh = {
    enable    = true;   # tells home-manager to create and manage ~/.zshrc
    # keep the bulk of interactive config in an editable repo file; the guard
    # avoids a broken shell if the repo isn't present at repoDir
    initContent = ''
      [ -f ${repoDir}/config/zsh/rc.zsh ] && source ${repoDir}/config/zsh/rc.zsh
    '';
  };
}
