# receives nixpkgs, nixpkgs-unstable, and the full inputs attrset from flake.nix
{ nixpkgs, nixpkgs-unstable, inputs, ... }:
{
  mkHost = { hostname, user ? "k", system ? "x86_64-linux" }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        # every host module can declare `inputs` as an arg to access flake inputs
        inherit inputs user;
        # every host module can declare `pkgs-unstable` to pull a newer package
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      modules = [
        # home-manager NixOS module — activates home-manager as part of nixos-rebuild
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs   = true;  # reuse system nixpkgs — no duplicate eval
          home-manager.useUserPackages = true;  # packages go to /etc/profiles/per-user/${user}
          # noctalia edits some app configs in place (alacritty.toml, starship.toml)
          # with `sed -i`, which replaces the home-manager symlink with a plain file.
          # Without this, the next rebuild aborts with "file would be clobbered";
          # with it, home-manager moves the stray file aside and re-links cleanly.
          home-manager.backupFileExtension = "hm-bak";
          home-manager.users.${user}   = import ../hosts/${hostname}/home.nix;
          home-manager.extraSpecialArgs = {
            inherit inputs user;
            repoDir = "/home/${user}/nix-config";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          };
        }
        ../hosts/${hostname}/default.nix
      ];
    };
}
