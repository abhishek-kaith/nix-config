# receives nixpkgs, nixpkgs-unstable, and the full inputs attrset from flake.nix
{ nixpkgs, nixpkgs-unstable, inputs, ... }:
{
  mkHost = { hostname, user ? "k", system ? "x86_64-linux" }:
    let
      # Evaluated ONCE and handed to both the NixOS and the home-manager modules.
      # Importing nixpkgs is the expensive part of an eval; doing it twice (as
      # this used to) cost a second full unstable eval on every rebuild.
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        # every host module can declare `inputs` as an arg to access flake inputs
        inherit inputs user;
        # every host module can declare `pkgs-unstable` to pull a newer package
        inherit pkgs-unstable;
      };
      modules = [
        # home-manager NixOS module — activates home-manager as part of nixos-rebuild
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs   = true;  # reuse system nixpkgs — no duplicate eval
          home-manager.useUserPackages = true;  # packages go to /etc/profiles/per-user/${user}
          # Safety net: when something outside nix has written a file home-manager
          # manages, the rebuild would abort with "file would be clobbered". With
          # this set, it moves the stray file aside and re-links cleanly instead.
          home-manager.backupFileExtension = "hm-bak";
          home-manager.users.${user}   = import ../hosts/${hostname}/home.nix;
          home-manager.extraSpecialArgs = {
            inherit inputs user pkgs-unstable;
            repoDir = "/home/${user}/nix-config";
          };
        }
        ../hosts/${hostname}/default.nix
      ];
    };
}
