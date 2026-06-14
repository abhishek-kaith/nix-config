{
  description = "k's NixOS configuration";

  inputs = {
    nixpkgs.url          = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    noctalia.url = "github:noctalia-dev/noctalia";
    # intentionally NOT following nixpkgs — noctalia cachix is built with its own nixpkgs;
    # overriding causes a hash mismatch and forces a full source compile
  };

  # inputs@ binds ALL inputs as a single attribute set called `inputs`
  # so we can pass the whole set to lib and down to every host module
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      lib = import ./lib { inherit nixpkgs nixpkgs-unstable inputs; };
    in
    {
      nixosConfigurations = {
        vm = lib.mkHost { hostname = "vm"; };
      };
    };
}
