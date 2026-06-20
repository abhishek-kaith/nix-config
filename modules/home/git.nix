{ repoDir, ... }:
{
  programs.git = {
    enable = true;
    # real settings live in the editable repo file; HM only adds an [include]
    includes = [ { path = "${repoDir}/config/git/config"; } ];
  };
}
