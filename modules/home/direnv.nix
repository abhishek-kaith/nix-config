{ ... }:
{
  # Per-directory environments: an `.envrc` with `use flake` auto-loads a project's
  # dev shell on `cd`. nix-direnv adds fast, GC-safe caching. Hooks into zsh
  # automatically (programs.zsh is enabled in modules/home/zsh.nix).
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
    silent            = true;  # suppress the per-directory export logspam
  };
}
