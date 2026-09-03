{ repoDir, ... }:
{
  programs.git = {
    enable = true;
    # Shared settings live in the editable repo file. Machine-local identity
    # lives outside the public repo and remains writable without a rebuild.
    includes = [
      { path = "${repoDir}/config/git/config"; }
      { path = "~/.config/git/local"; }
    ];
  };
}
